import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/models/notebook_model.dart';
import 'package:kitnote/state/workspace_state.dart';

void main() {
  group('WorkspaceState & NotebookModel Tests', () {
    test('NotebookModel copyWith clearFolderId clears folder assignment', () {
      final notebook = NotebookModel.createNew(
        id: 'nb1',
        title: 'Notebook 1',
        folderId: 'folder_123',
      );
      expect(notebook.folderId, equals('folder_123'));

      // copyWith without clearFolderId retains folderId
      final updated = notebook.copyWith(title: 'New Title');
      expect(updated.folderId, equals('folder_123'));

      // copyWith with clearFolderId: true unassigns folderId
      final cleared = notebook.copyWith(clearFolderId: true);
      expect(cleared.folderId, isNull);
    });

    test('closeTab preserves active notebook when closing a tab to the left', () {
      final workspace = WorkspaceState();
      workspace.openNotebook('nb_A');
      workspace.openNotebook('nb_B');
      workspace.openNotebook('nb_C');

      expect(workspace.openNotebookIds, equals(['nb_A', 'nb_B', 'nb_C']));
      // Select 'nb_C' (index 2)
      workspace.switchTab(2);
      expect(workspace.primaryNotebookId, equals('nb_C'));
      expect(workspace.activeTabIndex, equals(2));

      // Close 'nb_A' (index 0, to the left)
      workspace.closeTab(0);
      expect(workspace.openNotebookIds, equals(['nb_B', 'nb_C']));
      // 'nb_C' should still be the active primary notebook!
      expect(workspace.primaryNotebookId, equals('nb_C'));
      expect(workspace.activeTabIndex, equals(1));
    });

    test('closeTab selects adjacent tab when closing the active tab', () {
      final workspace = WorkspaceState();
      workspace.openNotebook('nb_A');
      workspace.openNotebook('nb_B');
      workspace.openNotebook('nb_C');

      workspace.switchTab(1); // 'nb_B'
      expect(workspace.primaryNotebookId, equals('nb_B'));

      // Close 'nb_B' (active tab)
      workspace.closeTab(1);
      expect(workspace.openNotebookIds, equals(['nb_A', 'nb_C']));
      // Switched to adjacent tab at index 1 ('nb_C')
      expect(workspace.primaryNotebookId, equals('nb_C'));
      expect(workspace.activeTabIndex, equals(1));
    });
  });
}
