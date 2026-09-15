import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/models/notebook_model.dart';
import 'package:kitnote/models/page_model.dart';
import 'package:kitnote/state/notebook_editor_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotebookEditorState Tests', () {
    late NotebookModel testNotebook;
    late NotebookEditorState state;

    setUp(() {
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
  });
}
