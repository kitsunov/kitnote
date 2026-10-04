import 'dart:io';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotebookEditorState Tests', () {
    late Directory tempDir;
    late NotebookModel testNotebook;
    late NotebookEditorState state;

    setUp(() async {
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
      await Future.delayed(const Duration(milliseconds: 10));
      StorageService.overrideBaseDir = null;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
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
  });
}
