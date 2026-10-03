import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/state/library_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
  });

  setUp(() async {
    final base = Directory('${Directory.systemTemp.path}/kitnote_data');
    if (await base.exists()) {
      await base.delete(recursive: true);
    }
  });

  group('LibraryState Trash and Folder Operations Tests', () {
    test('moveToTrash, restoreFromTrash, and trash getters', () async {
      final state = LibraryState(autoInit: false);
      await state.init();
      final nb1 = await state.createNotebook(title: 'Active Notebook');
      final nb2 = await state.createNotebook(title: 'Trash Candidate');

      expect(state.trashCount, equals(0));
      expect(state.trashNotebooks, isEmpty);
      expect(state.filteredNotebooks.any((n) => n.id == nb1.id), isTrue);
      expect(state.filteredNotebooks.any((n) => n.id == nb2.id), isTrue);

      // Move nb2 to trash
      await state.moveToTrash(nb2.id);

      expect(state.trashCount, equals(1));
      expect(state.trashNotebooks.length, equals(1));
      expect(state.trashNotebooks.first.id, equals(nb2.id));
      expect(state.trashNotebooks.first.isDeleted, isTrue);
      expect(state.trashNotebooks.first.deletedAt, isNotNull);

      // In standard view, nb2 should not appear in filteredNotebooks
      expect(state.filteredNotebooks.any((n) => n.id == nb2.id), isFalse);

      // In trash view, nb2 should appear in filteredNotebooks
      state.viewTrash(true);
      expect(state.isViewingTrash, isTrue);
      expect(state.filteredNotebooks.length, equals(1));
      expect(state.filteredNotebooks.first.id, equals(nb2.id));

      // Restore nb2 from trash
      await state.restoreFromTrash(nb2.id);
      expect(state.trashCount, equals(0));
      expect(state.trashNotebooks, isEmpty);

      state.viewTrash(false);
      expect(state.filteredNotebooks.any((n) => n.id == nb2.id), isTrue);
    });

    test('deleteNotebookPermanently and emptyTrash remove deleted notebooks', () async {
      final state = LibraryState(autoInit: false);
      await state.init();
      final nbA = await state.createNotebook(title: 'Delete Permanently Test');
      final nbB = await state.createNotebook(title: 'Empty Trash Test');

      await state.moveToTrash(nbA.id);
      await state.moveToTrash(nbB.id);
      expect(state.trashCount, equals(2));

      // Permanently delete nbA
      await state.deleteNotebookPermanently(nbA.id);
      expect(state.trashCount, equals(1));
      expect(state.trashNotebooks.first.id, equals(nbB.id));

      // Empty trash deletes nbB
      await state.emptyTrash();
      expect(state.trashCount, equals(0));
      expect(state.trashNotebooks, isEmpty);
    });

    test('moveNotebookToFolder moves notebook to folder and unassigns folder when null', () async {
      final state = LibraryState(autoInit: false);
      await state.init();
      final nb = await state.createNotebook(title: 'Folder Move Test');
      expect(nb.folderId, isNull);

      // Move to folder_study
      await state.moveNotebookToFolder(nb.id, 'folder_study');
      var updated = state.notebooks.firstWhere((n) => n.id == nb.id);
      expect(updated.folderId, equals('folder_study'));

      // Move back to no folder
      await state.moveNotebookToFolder(nb.id, null);
      updated = state.notebooks.firstWhere((n) => n.id == nb.id);
      expect(updated.folderId, isNull);
    });
  });
}
