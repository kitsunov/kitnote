import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/engine/shape_recognizer.dart';
import 'package:kitnote/models/notebook_model.dart';
import 'package:kitnote/models/page_model.dart';
import 'package:kitnote/models/page_template_model.dart';
import 'package:kitnote/models/point_model.dart';
import 'package:kitnote/models/stroke_model.dart';
import 'package:kitnote/models/tool_type.dart';
import 'package:kitnote/services/storage_service.dart';
import 'package:kitnote/state/notebook_editor_state.dart';
import 'package:kitnote/state/workspace_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotebookEditorState Tests', () {
    late Directory tempDir;
    late NotebookModel testNotebook;
    late NotebookEditorState state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('editor_state_test_');
      StorageService.overrideBaseDir = tempDir;
      testNotebook = NotebookModel(
        id: 'nb_test',
        title: 'Test Notebook',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pages: [
          const PageModel(
            id: 'page_0',
            pageIndex: 0,
          ),
        ],
      );
      state = NotebookEditorState(notebook: testNotebook);
    });

    tearDown(() async {
      state.dispose();
      await Future.delayed(const Duration(milliseconds: 25));
      StorageService.overrideBaseDir = null;
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('addTextElement and updateTextElement correctly modify page text', () {
      state.addTextElement('Original Note', const Offset(50, 100));
      expect(state.currentPage.textElements.length, equals(1));
      final textEl = state.currentPage.textElements.first;
      expect(textEl.text, equals('Original Note'));

      final updated = textEl.copyWith(text: 'Updated Note', isBold: true);
      state.updateTextElement(updated);
      expect(state.currentPage.textElements.first.text, equals('Updated Note'));
      expect(state.currentPage.textElements.first.isBold, isTrue);

      state.deleteTextElement(textEl.id);
      expect(state.currentPage.textElements, isEmpty);
    });

    test('addImageElement and deleteImageElement modify image elements list', () {
      state.addImageElement('/dummy/path.png', const Offset(20, 20), 200, 150);
      expect(state.currentPage.imageElements.length, equals(1));
      final img = state.currentPage.imageElements.first;
      expect(img.localPath, equals('/dummy/path.png'));

      final updated = img.copyWith(width: 300, height: 250);
      state.updateImageElement(updated);
      expect(state.currentPage.imageElements.first.width, equals(300));

      state.deleteImageElement(img.id);
      expect(state.currentPage.imageElements, isEmpty);
    });

    test('clearLassoSelection clears active lasso and selection sets', () {
      state.clearLassoSelection();
      expect(state.selectedStrokeIds, isEmpty);
      expect(state.lassoPoints, isEmpty);
      expect(state.isLassoActive, isFalse);
    });

    test('addNewPage, deletePageAt, and setActivePageIndex correctly manipulate pages', () {
      expect(state.notebook.pages.length, equals(1));

      state.addNewPage();
      expect(state.notebook.pages.length, equals(2));
      expect(state.notebook.pages[1].pageIndex, equals(1));

      state.addNewPage();
      expect(state.notebook.pages.length, equals(3));

      state.setActivePageIndex(1);
      expect(state.currentPageIndex, equals(1));

      state.deletePageAt(1);
      expect(state.notebook.pages.length, equals(2));
      // Reindexed correctly
      expect(state.notebook.pages[0].pageIndex, equals(0));
      expect(state.notebook.pages[1].pageIndex, equals(1));
    });

    test('document-level undo and redo properly handles page addition and deletion', () {
      expect(state.notebook.pages.length, equals(1));
      expect(state.canUndo, isFalse);

      // Add page 2
      state.addNewPage();
      expect(state.notebook.pages.length, equals(2));
      expect(state.currentPageIndex, equals(1));
      expect(state.canUndo, isTrue);

      // Undo page addition restores page count to 1
      state.undo();
      expect(state.notebook.pages.length, equals(1));
      expect(state.currentPageIndex, equals(0));
      expect(state.canRedo, isTrue);

      // Redo restores page 2
      state.redo();
      expect(state.notebook.pages.length, equals(2));
      expect(state.currentPageIndex, equals(1));

      // Delete page 2
      state.deleteCurrentPage();
      expect(state.notebook.pages.length, equals(1));

      // Undo deletion restores page 2
      state.undo();
      expect(state.notebook.pages.length, equals(2));
      expect(state.currentPageIndex, equals(1));
    });

    test('onNotebookChanged callback is invoked on edits', () {
      NotebookModel? notifiedNotebook;
      final editorWithCallback = NotebookEditorState(
        notebook: testNotebook,
        onNotebookChanged: (updated) {
          notifiedNotebook = updated;
        },
      );

      editorWithCallback.addNewPage();
      expect(notifiedNotebook, isNotNull);
      expect(notifiedNotebook!.pages.length, equals(2));
    });

    test('duplicatePageAt duplicates specified page at index + 1 and preserves order', () {
      final state = NotebookEditorState(notebook: testNotebook);
      state.addNewPage();
      expect(state.notebook.pages.length, equals(2));

      // Currently active is page 1 (second page). Duplicate page 0 (first page).
      state.duplicatePageAt(0);
      expect(state.notebook.pages.length, equals(3));
      expect(state.currentPageIndex, equals(1)); // new copy is at index 1
      expect(state.notebook.pages[0].pageIndex, equals(0));
      expect(state.notebook.pages[1].pageIndex, equals(1));
      expect(state.notebook.pages[2].pageIndex, equals(2));
    });

    test('syncNotebook updates notebook and adjusts current page index safely', () {
      final state = NotebookEditorState(notebook: testNotebook);
      state.addNewPage();
      state.setActivePageIndex(1);
      expect(state.currentPageIndex, equals(1));

      // Sync with notebook having only 1 page
      final singlePageNotebook = testNotebook.copyWith(pages: [testNotebook.pages.first]);
      state.syncNotebook(singlePageNotebook);

      expect(state.notebook.pages.length, equals(1));
      expect(state.currentPageIndex, equals(0));
    });

    test('scrollTargetPageIndex is set on goToPage and addNewPage and cleared on clearScrollTarget', () {
      final state = NotebookEditorState(notebook: testNotebook);
      state.addNewPage(); // adds page at index 1
      expect(state.scrollTargetPageIndex, equals(1));
      state.clearScrollTarget();
      expect(state.scrollTargetPageIndex, isNull);

      state.goToPage(0);
      expect(state.scrollTargetPageIndex, equals(0));
      expect(state.currentPageIndex, equals(0));

      // setActivePageIndex does NOT set scrollTargetPageIndex (only for inking/viewport tracking)
      state.clearScrollTarget();
      state.setActivePageIndex(1);
      expect(state.currentPageIndex, equals(1));
      expect(state.scrollTargetPageIndex, isNull);
    });

    test('saveStatus defaults to saved and tracks SaveStatus values', () {
      final state = NotebookEditorState(notebook: testNotebook);
      expect(state.saveStatus, equals(SaveStatus.saved));
      expect(SaveStatus.values.length, equals(3));
    });

    test('highlighterWidth and eraserRadius can be updated', () {
      final state = NotebookEditorState(notebook: testNotebook);
      expect(state.highlighterWidth, equals(24.0));
      state.setHighlighterWidth(36.0);
      expect(state.highlighterWidth, equals(36.0));

      expect(state.eraserRadius, equals(16.0));
      state.setEraserRadius(28.0);
      expect(state.eraserRadius, equals(28.0));
    });

    test('customPaletteColors can have colors appended', () {
      final state = NotebookEditorState(notebook: testNotebook);
      final initialCount = state.customPaletteColors.length;
      state.addCustomColor(0xFFFF0055);
      expect(state.customPaletteColors.length, equals(initialCount + 1));
      expect(state.customPaletteColors.contains(0xFFFF0055), isTrue);
      // Adding duplicate color does not create redundant entry
      state.addCustomColor(0xFFFF0055);
      expect(state.customPaletteColors.length, equals(initialCount + 1));
    });

    test('moveTextElement updates text position correctly', () {
      final state = NotebookEditorState(notebook: testNotebook);
      state.addTextElement('Hello', const Offset(10, 10));
      final textId = state.currentPage.textElements.first.id;
      state.moveTextElement(textId, const Offset(40, 50));
      final moved = state.currentPage.textElements.first;
      expect(moved.x, equals(40.0));
      expect(moved.y, equals(50.0));
    });

    test('moveImageElement and resizeImageElement update image geometry', () {
      final state = NotebookEditorState(notebook: testNotebook);
      state.addImageElement('/dummy.png', const Offset(10, 10), 100, 100);
      final imgId = state.currentPage.imageElements.first.id;

      state.moveImageElement(imgId, const Offset(20, 30));
      final moved = state.currentPage.imageElements.first;
      expect(moved.x, equals(20.0));
      expect(moved.y, equals(30.0));

      state.resizeImageElement(imgId, 150, 200);
      final resized = state.currentPage.imageElements.first;
      expect(resized.width, equals(150.0));
      expect(resized.height, equals(200.0));
    });

    test('duplicateLassoSelection and recolorLassoSelection operate on selected strokes', () {
      final state = NotebookEditorState(notebook: testNotebook);
      const stroke1 = StrokeModel(
        id: 's1',
        points: [
          Point2D(x: 10, y: 10, pressure: 1.0, timestamp: 0),
          Point2D(x: 20, y: 20, pressure: 1.0, timestamp: 10),
        ],
        colorValue: 0xFF000000,
        strokeWidth: 2.0,
        toolType: ToolType.ballpointPen,
      );
      final pageWithStroke = state.currentPage.copyWith(strokes: [stroke1]);
      final nb = state.notebook.copyWith(pages: [pageWithStroke]);
      state.syncNotebook(nb);
      expect(state.currentPage.strokes.length, equals(1));

      // Simulate lasso selecting stroke s1
      state.setTool(ToolType.lasso);
      state.startStroke(const Point2D(x: 0, y: 0, pressure: 1.0, timestamp: 0));
      state.appendStrokePoint(const Point2D(x: 100, y: 0, pressure: 1.0, timestamp: 10));
      state.appendStrokePoint(const Point2D(x: 100, y: 100, pressure: 1.0, timestamp: 20));
      state.appendStrokePoint(const Point2D(x: 0, y: 100, pressure: 1.0, timestamp: 30));
      state.finishStroke();

      expect(state.selectedStrokeIds.contains('s1'), isTrue);
      expect(state.lassoBoundingBox, isNotNull);

      // Recolor
      state.recolorLassoSelection(0xFFFF0000);
      expect(state.currentPage.strokes.first.colorValue, equals(0xFFFF0000));

      // Duplicate
      state.duplicateLassoSelection();
      expect(state.currentPage.strokes.length, equals(2));
      final duplicated = state.currentPage.strokes.last;
      expect(duplicated.colorValue, equals(0xFFFF0000));
      expect(duplicated.points.first.x, equals(34.0)); // shifted by 24px
    });

    test('ShapeRecognizer respects dwell time before snapping strokes', () {
      const points = [
        Point2D(x: 0, y: 0, pressure: 1.0, timestamp: 0),
        Point2D(x: 25, y: 0, pressure: 1.0, timestamp: 50),
        Point2D(x: 50, y: 0, pressure: 1.0, timestamp: 100),
        Point2D(x: 75, y: 0, pressure: 1.0, timestamp: 150),
        Point2D(x: 100, y: 0, pressure: 1.0, timestamp: 200),
      ];
      const stroke = StrokeModel(
        id: 'line_test',
        points: points,
        colorValue: 0xFF000000,
        strokeWidth: 2.0,
        toolType: ToolType.ballpointPen,
      );

      // Without dwell time (<350ms and no cluster at end), no snapping occurs
      final fastHandwriting = ShapeRecognizer.tryRecognizeShape(stroke, endDwellMs: 100);
      expect(fastHandwriting, isNull);

      // With deliberate dwell time (>=350ms), shape recognition snaps straight line
      final deliberateHold = ShapeRecognizer.tryRecognizeShape(stroke, endDwellMs: 400);
      expect(deliberateHold, isNotNull);
      expect(deliberateHold!.points.length, equals(2));
      expect(deliberateHold.points.first.x, equals(0.0));
      expect(deliberateHold.points.last.x, equals(100.0));
    });

    test('togglePageBookmark toggles isBookmarked status on page', () {
      expect(state.currentPage.isBookmarked, isFalse);

      state.togglePageBookmark(0);
      expect(state.currentPage.isBookmarked, isTrue);

      state.togglePageBookmark(0);
      expect(state.currentPage.isBookmarked, isFalse);
    });

    test('insertPageAfter inserts new page at index + 1 and preserves order', () {
      state.addNewPage();
      final page1Id = state.notebook.pages[1].id;
      expect(state.notebook.pages.length, equals(2));

      state.insertPageAfter(0);
      expect(state.notebook.pages.length, equals(3));
      expect(state.currentPageIndex, equals(1));
      expect(state.notebook.pages[0].id, equals('page_0'));
      expect(state.notebook.pages[2].id, equals(page1Id));
    });

    test('movePage moves page from one position to another', () {
      state.addNewPage();
      final page0Id = state.notebook.pages[0].id;
      final page1Id = state.notebook.pages[1].id;

      state.movePage(0, 1);
      expect(state.notebook.pages[0].id, equals(page1Id));
      expect(state.notebook.pages[1].id, equals(page0Id));
      expect(state.currentPageIndex, equals(1));
    });

    test('updateNotebookTemplate and updatePageTemplate update templates correctly', () {
      state.addNewPage();
      const newTemplate = PageTemplateModel(
        type: PaperTemplateType.musicSheet,
        colorTheme: PaperColorTheme.dark,
      );

      // Update single page template
      state.updatePageTemplate(0, newTemplate);
      expect(state.notebook.pages[0].template.type, equals(PaperTemplateType.musicSheet));
      expect(state.notebook.pages[0].template.colorTheme, equals(PaperColorTheme.dark));
      expect(state.notebook.pages[1].template.type, equals(PaperTemplateType.narrowRuled));

      // Update all pages template
      const allTemplate = PageTemplateModel(
        type: PaperTemplateType.dotGrid,
        colorTheme: PaperColorTheme.softSage,
      );
      state.updateNotebookTemplate(allTemplate);
      expect(state.notebook.pages[0].template.type, equals(PaperTemplateType.dotGrid));
      expect(state.notebook.pages[1].template.type, equals(PaperTemplateType.dotGrid));
    });

    test('lasso selection encompasses and duplicates text and image elements', () {
      state.addImageElement('/dummy/img.png', const Offset(10, 10), 50, 50);
      state.addTextElement('Lasso note', const Offset(20, 20));

      final imgId = state.currentPage.imageElements.first.id;
      final txtId = state.currentPage.textElements.first.id;

      // Select with lasso polygon enclosing (0,0) to (100,100)
      state.setTool(ToolType.lasso);
      state.startStroke(const Point2D(x: 0, y: 0, pressure: 1.0, timestamp: 0));
      state.appendStrokePoint(const Point2D(x: 100, y: 0, pressure: 1.0, timestamp: 10));
      state.appendStrokePoint(const Point2D(x: 100, y: 100, pressure: 1.0, timestamp: 20));
      state.appendStrokePoint(const Point2D(x: 0, y: 100, pressure: 1.0, timestamp: 30));
      state.finishStroke();

      expect(state.selectedImageIds.contains(imgId), isTrue);
      expect(state.selectedTextIds.contains(txtId), isTrue);

      // Duplicate selection
      state.duplicateLassoSelection();
      expect(state.currentPage.imageElements.length, equals(2));
      expect(state.currentPage.textElements.length, equals(2));

      // Translate selection
      state.translateLassoSelection(10.0, 15.0);
      final duplicatedImg = state.currentPage.imageElements.last;
      expect(duplicatedImg.x, equals(10 + 24 + 10.0));
    });

    test('pixel eraser splits strokes upon contact', () {
      state.setTool(ToolType.ballpointPen);
      state.startStroke(const Point2D(x: 0, y: 0, timestamp: 0));
      state.appendStrokePoint(const Point2D(x: 10, y: 0, timestamp: 1));
      state.appendStrokePoint(const Point2D(x: 20, y: 0, timestamp: 2));
      state.appendStrokePoint(const Point2D(x: 30, y: 0, timestamp: 3));
      state.appendStrokePoint(const Point2D(x: 40, y: 0, timestamp: 4));
      state.finishStroke();
      expect(state.currentPage.strokes.length, equals(1));

      // Erase at (20, 0) with pixel eraser (radius 6)
      state.setTool(ToolType.pixelEraser);
      state.setEraserRadius(6.0);
      state.startStroke(const Point2D(x: 20, y: 0, pressure: 1.0, timestamp: 10));
      state.finishStroke();

      // Should be split into 2 sub-strokes
      expect(state.currentPage.strokes.length, equals(2));
    });

    test('cross-page drag does not throw when element width exceeds page width', () {
      state.addNewPage();
      expect(state.notebook.pages.length, equals(2));
      state.setActivePageIndex(1);

      // Create an oversized text element (width 900 on 800px page)
      state.addTextElement('Oversized text box', const Offset(50, 50));
      final txt = state.currentPage.textElements.first;
      state.updateTextElement(txt.copyWith(width: 900.0));

      // Drag upward onto page 0
      expect(() => state.moveTextElementWithCrossPage(txt.id, const Offset(100, -60)), returnsNormally);
      expect(state.currentPageIndex, equals(0));

      // Create an oversized image element (width 1200 on 800px page)
      state.addImageElement('/dummy/path.png', const Offset(50, 50), 1200.0, 400.0);
      final img = state.currentPage.imageElements.first;

      // Drag downward onto page 1
      expect(() => state.moveImageElementWithCrossPage(img.id, Offset(100, state.currentPage.height + 40)), returnsNormally);
      expect(state.currentPageIndex, equals(1));
    });

    test('undo and redo clear active lasso selection', () {
      state.setTool(ToolType.ballpointPen);
      state.startStroke(const Point2D(x: 10, y: 10, timestamp: 0));
      state.appendStrokePoint(const Point2D(x: 20, y: 20, timestamp: 1));
      state.finishStroke();
      expect(state.currentPage.strokes.length, equals(1));

      // Set lasso selection
      state.setTool(ToolType.lasso);
      state.startStroke(const Point2D(x: 0, y: 0, timestamp: 0));
      state.appendStrokePoint(const Point2D(x: 30, y: 0, timestamp: 1));
      state.appendStrokePoint(const Point2D(x: 30, y: 30, timestamp: 2));
      state.appendStrokePoint(const Point2D(x: 0, y: 30, timestamp: 3));
      state.finishStroke();
      expect(state.selectedStrokeIds.isNotEmpty, isTrue);

      // Undo stroke creation
      state.undo();
      expect(state.selectedStrokeIds.isEmpty, isTrue);
      expect(state.selectedTextIds.isEmpty, isTrue);
      expect(state.selectedImageIds.isEmpty, isTrue);
      expect(state.lassoBoundingBox, isNull);

      // Redo stroke creation
      state.redo();
      expect(state.selectedStrokeIds.isEmpty, isTrue);
      expect(state.selectedTextIds.isEmpty, isTrue);
      expect(state.selectedImageIds.isEmpty, isTrue);
      expect(state.lassoBoundingBox, isNull);
    });

    test('deletePageAt decrements currentPageIndex when deleting an earlier page', () {
      state.addNewPage();
      state.addNewPage();
      expect(state.notebook.pages.length, equals(3));

      // User navigates to page 2 (index 2)
      state.setActivePageIndex(2);
      expect(state.currentPageIndex, equals(2));

      // Deleting page 0 shifts page 2 into page 1
      state.deletePageAt(0);
      expect(state.notebook.pages.length, equals(2));
      expect(state.currentPageIndex, equals(1));
    });

    test('undo stack is capped at maxUndoHistory to prevent OOM', () {
      for (int i = 0; i < 55; i++) {
        state.addTextElement('Item $i', Offset(10.0, i * 10.0));
      }
      expect(state.currentPage.textElements.length, equals(55));

      int undoCount = 0;
      while (state.canUndo) {
        state.undo();
        undoCount++;
      }
      expect(undoCount, equals(NotebookEditorState.maxUndoHistory));
      expect(state.currentPage.textElements.length, equals(55 - NotebookEditorState.maxUndoHistory));
    });

    test('live drag updates with recordUndo: false allow single-step undo of entire drag', () {
      state.addTextElement('Draggable', const Offset(100, 100));
      final id = state.currentPage.textElements.first.id;

      // Simulate gesture: panStart -> 10 panUpdates -> panEnd
      state.recordUndoSnapshot();
      for (int step = 1; step <= 10; step++) {
        state.moveTextElementWithCrossPage(
          id,
          Offset(100.0 + step * 10, 100.0 + step * 5),
          recordUndo: false,
          save: false,
        );
      }
      state.commitToStorage();

      expect(state.currentPage.textElements.first.x, equals(200.0));
      expect(state.currentPage.textElements.first.y, equals(150.0));

      // Single undo restores initial position (100, 100)
      state.undo();
      expect(state.currentPage.textElements.first.x, equals(100.0));
      expect(state.currentPage.textElements.first.y, equals(100.0));
    });

    test('calling notifyListeners after dispose does not throw', () {
      final tempState = NotebookEditorState(
        notebook: NotebookModel.createNew(id: 'nb_disp', title: 'Disp'),
      );
      tempState.dispose();
      expect(() => tempState.notifyListeners(), returnsNormally);
    });

    test('copyLassoSelection, cutLassoSelection, and pasteClipboard work across pages', () {
      state.addTextElement('Clipboard Text', const Offset(50, 50));
      expect(state.currentPage.textElements.length, equals(1));

      // Select with lasso
      state.setTool(ToolType.lasso);
      state.startStroke(const Point2D(x: 10, y: 10, timestamp: 1));
      state.appendStrokePoint(const Point2D(x: 350, y: 10, timestamp: 2));
      state.appendStrokePoint(const Point2D(x: 350, y: 200, timestamp: 3));
      state.appendStrokePoint(const Point2D(x: 10, y: 200, timestamp: 4));
      state.finishStroke(5);
      expect(state.selectedTextIds.length, equals(1));

      // Cut from page 0
      state.cutLassoSelection();
      expect(state.currentPage.textElements, isEmpty);
      expect(state.hasClipboardContent, isTrue);

      // Add page 1 and paste onto page 1
      state.addNewPage();
      expect(state.currentPageIndex, equals(1));
      state.pasteClipboard(dx: 30, dy: 40);

      expect(state.currentPage.textElements.length, equals(1));
      expect(state.currentPage.textElements.first.text, equals('Clipboard Text'));
      expect(state.currentPage.textElements.first.x, equals(80.0));
      expect(state.currentPage.textElements.first.y, equals(90.0));
    });

    test('laserPointer creates ephemeral laserStrokes without persisting or recording Undo', () {
      state.setTool(ToolType.laserPointer);
      expect(state.activeTool, equals(ToolType.laserPointer));

      state.startStroke(const Point2D(x: 20, y: 20, timestamp: 1));
      state.appendStrokePoint(const Point2D(x: 80, y: 80, timestamp: 2));
      state.finishStroke(3);

      expect(state.currentPage.strokes, isEmpty);
      expect(state.canUndo, isFalse);
      expect(state.laserStrokes.length, equals(1));
      expect(state.laserStrokes.first.toolType, equals(ToolType.laserPointer));

      state.clearLaserStrokes();
      expect(state.laserStrokes, isEmpty);
    });

    test('clearPageAt and clearCurrentPage wipe strokes and elements on page and support Undo', () {
      state.addTextElement('Note 1', const Offset(30, 30));
      state.addImageElement('/test.png', const Offset(50, 50), 100, 100);
      expect(state.currentPage.textElements.length, equals(1));
      expect(state.currentPage.imageElements.length, equals(1));

      state.clearCurrentPage();
      expect(state.currentPage.textElements, isEmpty);
      expect(state.currentPage.imageElements, isEmpty);
      expect(state.currentPage.strokes, isEmpty);

      // Undo restores cleared page content
      state.undo();
      expect(state.currentPage.textElements.length, equals(1));
      expect(state.currentPage.imageElements.length, equals(1));
    });

    test('scaleLassoSelection scales strokes, text elements, and images and supports Undo', () {
      state.setTool(ToolType.ballpointPen);
      state.startStroke(const Point2D(x: 20, y: 20, timestamp: 1));
      state.appendStrokePoint(const Point2D(x: 40, y: 40, timestamp: 2));
      state.finishStroke(3);

      state.addTextElement('Scale Me', const Offset(30, 30));
      state.addImageElement('/img.png', const Offset(25, 25), 50, 50);

      // Select all with lasso
      state.setTool(ToolType.lasso);
      state.startStroke(const Point2D(x: 0, y: 0, timestamp: 10));
      state.appendStrokePoint(const Point2D(x: 400, y: 0, timestamp: 11));
      state.appendStrokePoint(const Point2D(x: 400, y: 300, timestamp: 12));
      state.appendStrokePoint(const Point2D(x: 0, y: 300, timestamp: 13));
      state.finishStroke(14);

      expect(state.selectedStrokeIds.length, equals(1));
      expect(state.selectedTextIds.length, equals(1));
      expect(state.selectedImageIds.length, equals(1));

      final origImgW = state.currentPage.imageElements.first.width;
      final origFontSize = state.currentPage.textElements.first.fontSize;

      state.scaleLassoSelection(1.2, anchor: const Offset(20, 20));
      expect(state.currentPage.imageElements.first.width, closeTo(origImgW * 1.2, 0.01));
      expect(state.currentPage.textElements.first.fontSize, closeTo(origFontSize * 1.2, 0.01));

      state.undo();
      expect(state.currentPage.imageElements.first.width, closeTo(origImgW, 0.01));
      expect(state.currentPage.textElements.first.fontSize, closeTo(origFontSize, 0.01));
    });

    test('rotateImageElement rotates image by 90 degrees and supports Undo', () {
      state.addImageElement('/img.png', const Offset(50, 50), 100, 100);
      final imgId = state.currentPage.imageElements.first.id;
      expect(state.currentPage.imageElements.first.rotation, equals(0.0));

      state.rotateImageElement(imgId, math.pi / 2);
      expect(state.currentPage.imageElements.first.rotation, closeTo(math.pi / 2, 0.001));

      state.undo();
      expect(state.currentPage.imageElements.first.rotation, equals(0.0));
    });

    test('last opened page index and WorkspaceState open tabs persist via SharedPreferences', () async {
      state.addNewPage();
      state.addNewPage();
      state.goToPage(2);
      await Future.delayed(const Duration(milliseconds: 20));

      final reopenedState = NotebookEditorState(notebook: state.notebook);
      await reopenedState.loadLastOpenedPage();
      expect(reopenedState.currentPageIndex, equals(2));

      final ws1 = WorkspaceState();
      ws1.openNotebook('nb_1');
      ws1.openNotebook('nb_2');
      ws1.switchTab(0);
      await Future.delayed(const Duration(milliseconds: 20));

      final ws2 = WorkspaceState();
      await ws2.restoreSession();
      expect(ws2.openNotebookIds, equals(['nb_1', 'nb_2']));
      expect(ws2.activeTabIndex, equals(0));
    });

    test('ShapeRecognizer distinguishes circle vs rectangle, recognizes triangles, and snaps axis lines', () {
      // 1. Nearly horizontal line (2 degrees off) snaps to exact y
      final slightTiltLine = StrokeModel(
        id: 'tilt_line',
        points: List.generate(
          10,
          (i) => Point2D(x: i * 20.0, y: 100.0 + i * 0.4, timestamp: i * 10),
        ),
        colorValue: 0xFF000000,
        strokeWidth: 2.0,
        toolType: ToolType.ballpointPen,
      );
      final snappedLine = ShapeRecognizer.tryRecognizeShape(slightTiltLine, endDwellMs: 400);
      expect(snappedLine, isNotNull);
      expect(snappedLine!.points.length, equals(2));
      expect(snappedLine.points.first.y, closeTo(snappedLine.points.last.y, 0.001));

      // 2. Circle (radial error near 0) is recognized as 49-point smooth circle/ellipse
      final circlePts = <Point2D>[];
      for (int i = 0; i <= 32; i++) {
        final angle = (i / 32) * 2 * math.pi;
        circlePts.add(Point2D(
          x: 200.0 + 60.0 * math.cos(angle),
          y: 200.0 + 60.0 * math.sin(angle),
          timestamp: i * 10,
        ));
      }
      final circleStroke = StrokeModel(
        id: 'circle_1',
        points: circlePts,
        colorValue: 0xFF000000,
        strokeWidth: 2.0,
        toolType: ToolType.ballpointPen,
      );
      final recognizedCircle = ShapeRecognizer.tryRecognizeShape(circleStroke, endDwellMs: 400);
      expect(recognizedCircle, isNotNull);
      expect(recognizedCircle!.points.length, equals(29)); // 28 segments + 1 closing point

      // 3. Square (4 corners) is recognized as 5-point closed rectangle, NOT a circle
      final squarePts = <Point2D>[
        for (int i = 0; i <= 8; i++) Point2D(x: 100.0 + i * 15.0, y: 100.0, timestamp: i * 10),
        for (int i = 1; i <= 8; i++) Point2D(x: 220.0, y: 100.0 + i * 15.0, timestamp: 90 + i * 10),
        for (int i = 1; i <= 8; i++) Point2D(x: 220.0 - i * 15.0, y: 220.0, timestamp: 180 + i * 10),
        for (int i = 1; i <= 8; i++) Point2D(x: 100.0, y: 220.0 - i * 15.0, timestamp: 270 + i * 10),
      ];
      final squareStroke = StrokeModel(
        id: 'square_1',
        points: squarePts,
        colorValue: 0xFF000000,
        strokeWidth: 2.0,
        toolType: ToolType.ballpointPen,
      );
      final recognizedSquare = ShapeRecognizer.tryRecognizeShape(squareStroke, endDwellMs: 400);
      expect(recognizedSquare, isNotNull);
      expect(recognizedSquare!.points.length, equals(5)); // 4 corners + closing point

      // 4. Triangle (3 sharp vertices) is recognized as 4-point closed triangle
      final triPts = <Point2D>[
        for (int i = 0; i <= 8; i++)
          Point2D(x: 100.0 + i * 10.0, y: 200.0 - i * 15.0, timestamp: i * 10),
        for (int i = 1; i <= 8; i++)
          Point2D(x: 180.0 + i * 10.0, y: 80.0 + i * 15.0, timestamp: 90 + i * 10),
        for (int i = 1; i <= 8; i++)
          Point2D(x: 260.0 - i * 20.0, y: 200.0, timestamp: 180 + i * 10),
      ];
      final triStroke = StrokeModel(
        id: 'tri_1',
        points: triPts,
        colorValue: 0xFF000000,
        strokeWidth: 2.0,
        toolType: ToolType.ballpointPen,
      );
      final recognizedTri = ShapeRecognizer.tryRecognizeShape(triStroke, endDwellMs: 400);
      expect(recognizedTri, isNotNull);
      expect(recognizedTri!.points.length, equals(4)); // 3 vertices + closing point
    });

    test('live hold-to-snap snaps active stroke while stylus is held still', () async {
      state.setTool(ToolType.fountainPen);
      state.startStroke(const Point2D(x: 10, y: 50, timestamp: 0));
      for (int i = 1; i <= 8; i++) {
        state.appendStrokePoint(Point2D(x: 10.0 + i * 20.0, y: 50.0, timestamp: i * 15));
      }
      expect(state.activeStrokePoints.length, equals(9));

      // Hold stylus still for > 380ms
      await Future.delayed(const Duration(milliseconds: 430));
      // Active stroke points should now be snapped live to a 2-point straight line!
      expect(state.activeStrokePoints.length, equals(2));

      state.finishStroke();
      expect(state.currentPage.strokes.length, equals(1));
      expect(state.currentPage.strokes.first.points.length, equals(2));
    });

    test('snapRulerToNextPresetAngle cycles through 0, 45, 90, 135 degrees and searchInNotebook finds text', () {
      expect(state.rulerAngle, closeTo(0.0, 0.001));
      state.snapRulerToNextPresetAngle();
      expect(state.rulerAngle, closeTo(math.pi / 4, 0.001));
      state.snapRulerToNextPresetAngle();
      expect(state.rulerAngle, closeTo(math.pi / 2, 0.001));
      state.snapRulerToNextPresetAngle();
      expect(state.rulerAngle, closeTo(3 * math.pi / 4, 0.001));
      state.snapRulerToNextPresetAngle();
      expect(state.rulerAngle, closeTo(0.0, 0.001));

      // Search across pages
      state.addTextElement('Calculus lecture derivatives', const Offset(20, 20));
      state.addNewPage();
      state.addTextElement('Linear Algebra eigenvalues', const Offset(40, 40));

      final matches = state.searchInNotebook('eigen');
      expect(matches.length, equals(1));
      expect(matches.first.pageIndex, equals(1));
      expect(matches.first.pageNumber, equals(2));
      expect(matches.first.previewText, contains('eigenvalues'));
    });
  });
}
