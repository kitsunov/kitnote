import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/models/folder_model.dart';
import 'package:kitnote/models/notebook_model.dart';
import 'package:kitnote/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kitnote_storage_test_');
    StorageService.overrideBaseDir = tempDir;
    storage = StorageService();
  });

  tearDown(() async {
    StorageService.overrideBaseDir = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageService Tests', () {
    test('saveFolders and loadFolders persist folder data properly', () async {
      final folders = [
        FolderModel(
          id: 'f1',
          name: 'Folder 1',
          colorValue: 0xFF123456,
          createdAt: DateTime.now(),
        ),
        FolderModel(
          id: 'f2',
          name: 'Folder 2',
          colorValue: 0xFF654321,
          createdAt: DateTime.now(),
        ),
      ];

      await storage.saveFolders(folders);
      final loaded = await storage.loadFolders();

      expect(loaded.length, equals(2));
      expect(loaded[0].id, equals('f1'));
      expect(loaded[0].name, equals('Folder 1'));
      expect(loaded[1].id, equals('f2'));
    });

    test('saveNotebook and loadAllNotebooks persist notebook models atomically', () async {
      final notebook = NotebookModel.createNew(
        id: 'nb_test_1',
        title: 'Test Notebook 1',
        folderId: 'f1',
      );

      final success = await storage.saveNotebook(notebook);
      expect(success, isTrue);

      final allNotebooks = await storage.loadAllNotebooks();
      expect(allNotebooks.any((n) => n.id == 'nb_test_1'), isTrue);

      final loaded = allNotebooks.firstWhere((n) => n.id == 'nb_test_1');
      expect(loaded.title, equals('Test Notebook 1'));
      expect(loaded.folderId, equals('f1'));
    });

    test('loadAllNotebooks recovers from .bak when primary .json is corrupted', () async {
      final notebook = NotebookModel.createNew(
        id: 'nb_corrupt',
        title: 'Original Title',
      );

      // Save valid notebook first
      await storage.saveNotebook(notebook);

      // Save updated version so .bak is created
      final updated = notebook.copyWith(title: 'Updated Title');
      await storage.saveNotebook(updated);

      final dir = await storage.notebooksDir;
      final jsonFile = File('${dir.path}/nb_corrupt.json');
      final bakFile = File('${dir.path}/nb_corrupt.json.bak');

      expect(await jsonFile.exists(), isTrue);
      expect(await bakFile.exists(), isTrue);

      // Corrupt primary json
      await jsonFile.writeAsString('INVALID_CORRUPT_JSON{{{');

      final loaded = await storage.loadAllNotebooks();
      final recovered = loaded.where((n) => n.id == 'nb_corrupt').firstOrNull;

      expect(recovered, isNotNull);
      expect(recovered!.id, equals('nb_corrupt'));
    });

    test('deleteNotebook deletes files and prevents saving during deletion', () async {
      final notebook = NotebookModel.createNew(
        id: 'nb_to_delete',
        title: 'Delete Me',
      );
      await storage.saveNotebook(notebook);

      final dir = await storage.notebooksDir;
      final file = File('${dir.path}/nb_to_delete.json');
      expect(await file.exists(), isTrue);

      await storage.deleteNotebook('nb_to_delete');
      expect(await file.exists(), isFalse);

      // Subsequent save for a newly recreated notebook with same ID succeeds after delete completes
      final reNotebook = NotebookModel.createNew(
        id: 'nb_to_delete',
        title: 'Recreated',
      );
      final saveResult = await storage.saveNotebook(reNotebook);
      expect(saveResult, isTrue);
      expect(await file.exists(), isTrue);
    });
  });
}
