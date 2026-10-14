import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/models/folder_model.dart';
import 'package:kitnote/models/image_element_model.dart';
import 'package:kitnote/models/notebook_model.dart';
import 'package:kitnote/models/text_element_model.dart';
import 'package:kitnote/services/export_service.dart';
import 'package:kitnote/services/storage_service.dart';
import 'package:kitnote/services/update_service.dart';
import 'package:kitnote/state/library_state.dart';

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

    test('sanitizeId strips path traversal characters', () {
      expect(StorageService.sanitizeId('../../etc/passwd'), equals('etcpasswd'));
      expect(StorageService.sanitizeId('nb_123-abc'), equals('nb_123-abc'));
      expect(StorageService.sanitizeId('///...\\\\'), equals('default_id'));
    });

    test('copyImageToPermanentStorage copies image and deleteNotebook cleans it up', () async {
      final sourceImg = File('${tempDir.path}/picker_temp.jpg');
      await sourceImg.writeAsBytes([1, 2, 3, 4, 5]);

      final permanentPath = await storage.copyImageToPermanentStorage(
        sourceImg.path,
        'nb_img_test',
        'img_01',
      );

      final permFile = File(permanentPath);
      expect(await permFile.exists(), isTrue);
      expect(permanentPath.endsWith('nb_img_test_img_01.jpg'), isTrue);

      await storage.deleteNotebook('nb_img_test');
      expect(await permFile.exists(), isFalse);
    });

    test('UpdateService.isTrustedDownloadUrl validates HTTPS and GitHub domains', () {
      expect(
        UpdateService.isTrustedDownloadUrl('https://github.com/kitsunov/kitnote/releases/download/v1.0.9/KitNote.apk'),
        isTrue,
      );
      expect(
        UpdateService.isTrustedDownloadUrl('https://objects.githubusercontent.com/github-production-release-asset/KitNote.apk'),
        isTrue,
      );
      expect(
        UpdateService.isTrustedDownloadUrl('http://github.com/kitsunov/kitnote/releases/download/v1.0.9/KitNote.apk'),
        isFalse,
      );
      expect(
        UpdateService.isTrustedDownloadUrl('https://evil-attacker.com/github.com/KitNote.apk'),
        isFalse,
      );
    });

    test('exportKitNoteBackup and importKitNoteBackup preserve pages, text, images, and PDF', () async {
      final fakePdf = File('${tempDir.path}/sample.pdf');
      await fakePdf.writeAsBytes([37, 80, 68, 70, 45, 49, 46, 52]); // %PDF-1.4

      final fakeImg = File('${tempDir.path}/sample_img.png');
      await fakeImg.writeAsBytes([137, 80, 78, 71, 1, 2, 3, 4]);

      var nb = NotebookModel.createNew(id: 'nb_backup_orig', title: 'Лекция по физике');
      final page0 = nb.pages.first.copyWith(
        textElements: [
          const TextElementModel(
            id: 'txt_1',
            text: 'Закон сохранения энергии',
            x: 50,
            y: 60,
            colorValue: 0xFF000000,
          ),
        ],
        imageElements: [
          ImageElementModel(
            id: 'img_1',
            localPath: fakeImg.path,
            x: 100,
            y: 120,
            width: 200,
            height: 150,
          ),
        ],
      );
      nb = nb.copyWith(
        sourcePdfPath: fakePdf.path,
        pages: [page0],
      );

      final backupFile = await storage.exportKitNoteBackup(nb);
      expect(backupFile, isNotNull);
      expect(await backupFile!.exists(), isTrue);

      final restored = await storage.importKitNoteBackup(
        backupFile.path,
        newNotebookId: 'nb_backup_restored',
      );
      expect(restored, isNotNull);
      expect(restored!.id, equals('nb_backup_restored'));
      expect(restored.title, equals('Лекция по физике'));
      expect(restored.pages.first.textElements.first.text, equals('Закон сохранения энергии'));
      expect(restored.sourcePdfPath, isNotNull);
      expect(await File(restored.sourcePdfPath!).exists(), isTrue);
      expect(restored.pages.first.imageElements.first.localPath, isNotNull);
      expect(await File(restored.pages.first.imageElements.first.localPath!).exists(), isTrue);
    });

    test('ExportService.sanitizeTextForFont preserves Unicode or transliterates Cyrillic on fallback', () {
      expect(
        ExportService.sanitizeTextForFont('Привет Мир 123', isUnicodeFont: true),
        equals('Привет Мир 123'),
      );
      expect(
        ExportService.sanitizeTextForFont('Привет Мир 123', isUnicodeFont: false),
        equals('Privet Mir 123'),
      );
    });

    test('LibraryState full-text search matches text elements inside pages and locates page index', () async {
      final lib = LibraryState(autoInit: false);
      final nb = await lib.createNotebook(title: 'General Notes');
      final page1 = nb.pages.first;
      final page2 = page1.copyWith(
        id: 'p2',
        pageIndex: 1,
        textElements: [
          const TextElementModel(
            id: 't_quantum',
            text: 'Уравнение Шрёдингера и квантовая механика',
            x: 20,
            y: 40,
            colorValue: 0xFF000000,
          ),
        ],
      );
      final updatedNb = nb.copyWith(pages: [page1, page2]);
      await lib.updateNotebook(updatedNb);

      lib.setSearchQuery('шрёдингера');
      expect(lib.filteredNotebooks.length, equals(1));
      expect(lib.filteredNotebooks.first.id, equals(nb.id));
      expect(lib.findFirstMatchingPageIndex(updatedNb), equals(1));

      lib.setSearchQuery('несуществующий_текст_xyz');
      expect(lib.filteredNotebooks, isEmpty);
      lib.dispose();
    });

    test('LibraryState renameNotebook, renameFolder, and LibrarySortOrder work as expected', () async {
      final lib = LibraryState(autoInit: false);
      await lib.createFolder('Old Folder');
      final folderId = lib.folders.first.id;
      await lib.renameFolder(folderId, 'New Folder Name', colorValue: 0xFF10B981);
      expect(lib.folders.first.name, equals('New Folder Name'));
      expect(lib.folders.first.colorValue, equals(0xFF10B981));

      final nbA = await lib.createNotebook(title: 'Zeta Notebook');
      final nbB = await lib.createNotebook(title: 'Alpha Notebook');

      // Rename nbA and change cover color
      await lib.renameNotebook(nbA.id, 'Beta Notebook', coverColor: 0xFF9333EA);
      final updatedA = lib.notebooks.firstWhere((n) => n.id == nbA.id);
      expect(updatedA.title, equals('Beta Notebook'));
      expect(updatedA.coverColor, equals(0xFF9333EA));

      // Sort by title A-Z
      lib.setSortOrder(LibrarySortOrder.titleAsc);
      expect(lib.filteredNotebooks.first.title, equals('Alpha Notebook'));
      expect(lib.filteredNotebooks.last.title, equals('Beta Notebook'));

      // Add pages to Beta Notebook and sort by pageCountDesc
      final extraPages = [
        ...updatedA.pages,
        updatedA.pages.first.copyWith(id: 'p_extra_1', pageIndex: 1),
        updatedA.pages.first.copyWith(id: 'p_extra_2', pageIndex: 2),
      ];
      await lib.updateNotebook(updatedA.copyWith(pages: extraPages));
      lib.setSortOrder(LibrarySortOrder.pageCountDesc);
      expect(lib.filteredNotebooks.first.id, equals(nbA.id));
      expect(lib.filteredNotebooks.last.id, equals(nbB.id));
      lib.dispose();
    });

    test('LibraryState togglePinNotebook sorts pinned notebooks first and updateNotebookTags filters by tag', () async {
      final lib = LibraryState(autoInit: false);
      final nb1 = await lib.createNotebook(title: 'First Notebook');
      await Future.delayed(const Duration(milliseconds: 5));
      final nb2 = await lib.createNotebook(title: 'Second Notebook');

      // By default updatedDesc puts nb2 first
      expect(lib.filteredNotebooks.first.id, equals(nb2.id));

      // Pin nb1 -> nb1 should appear first despite older updatedAt or title order
      await lib.togglePinNotebook(nb1.id);
      lib.setSortOrder(LibrarySortOrder.titleAsc);
      expect(lib.filteredNotebooks.first.id, equals(nb1.id));
      expect(lib.filteredNotebooks.first.isPinned, isTrue);

      // Update tags on nb2 and search by tag
      await lib.updateNotebookTags(nb2.id, ['physics', 'exam', 'physics']);
      final updatedNb2 = lib.notebooks.firstWhere((n) => n.id == nb2.id);
      expect(updatedNb2.tags, equals(['physics', 'exam']));

      lib.setSearchQuery('physics');
      expect(lib.filteredNotebooks.length, equals(1));
      expect(lib.filteredNotebooks.first.id, equals(nb2.id));

      // Available tags sorted alphabetically
      await lib.updateNotebookTags(nb1.id, ['work', 'algebra']);
      expect(lib.allAvailableTags, equals(['algebra', 'exam', 'physics', 'work']));

      // Duplicate notebook creates an independent copy with copied tags and pages
      final duplicated = await lib.duplicateNotebook(nb1.id);
      expect(duplicated, isNotNull);
      expect(duplicated!.id, isNot(equals(nb1.id)));
      expect(duplicated.title, equals('First Notebook (Copy)'));
      expect(duplicated.tags, equals(['work', 'algebra']));
      expect(duplicated.isPinned, isFalse);
      expect(lib.notebooks.length, equals(3));

      lib.dispose();
    });
  });
}
