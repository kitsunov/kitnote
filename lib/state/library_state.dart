import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../engine/pdf_virtual_cache.dart';
import '../models/folder_model.dart';
import '../models/image_element_model.dart';
import '../models/notebook_model.dart';
import '../models/page_model.dart';
import '../models/page_template_model.dart';
import '../services/google_drive_service.dart';
import '../services/storage_service.dart';
import 'notebook_editor_state.dart';

enum LibrarySortOrder {
  updatedDesc,
  titleAsc,
  pageCountDesc,
}

class LibraryState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final GoogleDriveService _googleDrive = GoogleDriveService();

  List<NotebookModel> _notebooks = [];
  List<FolderModel> _folders = [];
  String? _selectedFolderId;
  String _searchQuery = '';
  LibrarySortOrder _sortOrder = LibrarySortOrder.updatedDesc;
  bool _isLoading = false;
  bool _isViewingTrash = false;

  List<NotebookModel> get notebooks => _notebooks;
  List<FolderModel> get folders => _folders;
  String? get selectedFolderId => _selectedFolderId;
  String get searchQuery => _searchQuery;
  LibrarySortOrder get sortOrder => _sortOrder;
  bool get isLoading => _isLoading;
  bool get isViewingTrash => _isViewingTrash;
  int get trashCount => _notebooks.where((nb) => nb.isDeleted).length;
  List<NotebookModel> get trashNotebooks => _notebooks.where((nb) => nb.isDeleted).toList();
  GoogleDriveService get googleDrive => _googleDrive;

  List<String> get allAvailableTags {
    final tagSet = <String>{};
    for (final nb in _notebooks) {
      if (!nb.isDeleted) {
        tagSet.addAll(nb.tags);
      }
    }
    final list = tagSet.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  LibraryState({bool autoInit = true}) {
    if (autoInit) {
      init();
    }
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _googleDrive.init();
    _folders = await _storage.loadFolders();
    _notebooks = await _storage.loadAllNotebooks();

    _isLoading = false;
    notifyListeners();
  }

  void selectFolder(String? folderId) {
    _isViewingTrash = false;
    _selectedFolderId = folderId;
    notifyListeners();
  }

  void viewTrash(bool viewing) {
    _isViewingTrash = viewing;
    if (viewing) {
      _selectedFolderId = null;
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOrder(LibrarySortOrder order) {
    if (_sortOrder != order) {
      _sortOrder = order;
      notifyListeners();
    }
  }

  List<NotebookModel> get filteredNotebooks {
    final filtered = _notebooks.where((nb) {
      if (_isViewingTrash) {
        if (!nb.isDeleted) return false;
      } else {
        if (nb.isDeleted) return false;
        if (_selectedFolderId != null && nb.folderId != _selectedFolderId) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = nb.title.toLowerCase().contains(query);
        final matchesTag = nb.tags.any((t) => t.toLowerCase().contains(query));
        final matchesPageText = nb.pages.any(
          (page) => page.textElements.any((t) => t.text.toLowerCase().contains(query)),
        );
        return matchesTitle || matchesTag || matchesPageText;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      switch (_sortOrder) {
        case LibrarySortOrder.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case LibrarySortOrder.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case LibrarySortOrder.pageCountDesc:
          final cmp = b.pageCount.compareTo(a.pageCount);
          return cmp != 0 ? cmp : b.updatedAt.compareTo(a.updatedAt);
      }
    });
    return filtered;
  }

  /// Finds the first 0-based page index where a text element matches the search query.
  int? findFirstMatchingPageIndex(NotebookModel nb, [String? customQuery]) {
    final q = (customQuery ?? _searchQuery).trim().toLowerCase();
    if (q.isEmpty) return null;
    for (int i = 0; i < nb.pages.length; i++) {
      final hasMatch = nb.pages[i].textElements.any(
        (t) => t.text.toLowerCase().contains(q),
      );
      if (hasMatch) return i;
    }
    return null;
  }

  Future<NotebookModel> createNotebook({
    required String title,
    String? folderId,
    int coverColor = 0xFF2563EB,
    PaperTemplateType templateType = PaperTemplateType.narrowRuled,
    PaperColorTheme paperTheme = PaperColorTheme.ivory,
  }) async {
    final id = const Uuid().v4();
    final notebook = NotebookModel.createNew(
      id: id,
      title: title,
      folderId: folderId ?? _selectedFolderId,
      coverColor: coverColor,
      templateType: templateType,
      paperTheme: paperTheme,
    );

    _notebooks.insert(0, notebook);
    await _storage.saveNotebook(notebook);
    notifyListeners();
    return notebook;
  }

  /// Creates an independent deep copy of an existing notebook (including PDF and embedded images).
  Future<NotebookModel?> duplicateNotebook(String notebookId, {String? copyTitle}) async {
    final sourceIndex = _notebooks.indexWhere((n) => n.id == notebookId);
    if (sourceIndex == -1) return null;
    final source = _notebooks[sourceIndex];
    final newId = const Uuid().v4();

    String? newPdfPath = source.sourcePdfPath;
    if (source.sourcePdfPath != null && source.sourcePdfPath!.isNotEmpty) {
      final srcPdf = File(source.sourcePdfPath!);
      if (await srcPdf.exists()) {
        final pdfsDir = await _storage.pdfsDir;
        newPdfPath = '${pdfsDir.path}/$newId.pdf';
        await srcPdf.copy(newPdfPath);
      }
    }

    final copiedPages = <PageModel>[];
    for (int i = 0; i < source.pages.length; i++) {
      final p = source.pages[i];
      final copiedImages = <ImageElementModel>[];
      for (final img in p.imageElements) {
        final newImgId = const Uuid().v4();
        String? newImgPath = img.localPath;
        if (img.localPath != null && img.localPath!.isNotEmpty) {
          final srcFile = File(img.localPath!);
          if (await srcFile.exists()) {
            newImgPath = await _storage.copyImageToPermanentStorage(
              img.localPath!,
              newId,
              newImgId,
            );
          }
        }
        copiedImages.add(img.copyWith(id: newImgId, localPath: newImgPath));
      }

      copiedPages.add(
        p.copyWith(
          id: '${newId}_p$i',
          pageIndex: i,
          imageElements: copiedImages,
        ),
      );
    }

    final now = DateTime.now();
    final duplicated = NotebookModel(
      id: newId,
      title: (copyTitle != null && copyTitle.trim().isNotEmpty)
          ? copyTitle.trim()
          : '${source.title} (Copy)',
      folderId: source.folderId,
      createdAt: now,
      updatedAt: now,
      coverColor: source.coverColor,
      sourcePdfPath: newPdfPath,
      pdfTotalPages: source.pdfTotalPages,
      isDeleted: false,
      isPinned: false,
      tags: List<String>.from(source.tags),
      pages: copiedPages,
    );

    _notebooks.insert(0, duplicated);
    await _storage.saveNotebook(duplicated);
    notifyListeners();
    return duplicated;
  }

  /// Exports a full editable `.kitnote` backup file for [notebook].
  Future<File?> exportNotebookBackup(NotebookModel notebook, {String? targetFilePath}) {
    return _storage.exportKitNoteBackup(notebook, targetFilePath: targetFilePath);
  }

  /// Imports a `.kitnote` backup file from disk and adds it to the library.
  Future<NotebookModel?> importNotebookBackupFromFile(String filePath) async {
    final restored = await _storage.importKitNoteBackup(
      filePath,
      newNotebookId: const Uuid().v4(),
    );
    if (restored != null) {
      _notebooks.insert(0, restored);
      notifyListeners();
    }
    return restored;
  }

  /// Import a PDF file (or `.kitnote` backup archive) and create a notebook for it
  Future<NotebookModel?> importPdfNotebook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'kitnote'],
      );

      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      final name = result.files.single.name;
      final rawBytes = result.files.single.bytes;
      if (path == null && rawBytes == null) return null;

      if (name.toLowerCase().endsWith('.kitnote') && path != null) {
        return await importNotebookBackupFromFile(path);
      }

      final id = const Uuid().v4();
      final title = name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

      // Ensure file is copied to permanent app storage
      final pdfsDir = await _storage.pdfsDir;
      final permanentPdfPath = '${pdfsDir.path}/$id.pdf';
      final targetFile = File(permanentPdfPath);

      if (path != null && await File(path).exists()) {
        await File(path).copy(permanentPdfPath);
      } else if (rawBytes != null) {
        await targetFile.writeAsBytes(rawBytes, flush: true);
      }

      // Dynamically resolve total page count from PDF binary
      int totalPages = 1;
      if (await targetFile.exists()) {
        totalPages = await PdfVirtualCache.getPdfPageCountFromFile(targetFile);
      } else if (rawBytes != null) {
        totalPages = PdfVirtualCache.getPdfPageCountFromBytes(rawBytes);
      }

      // Pre-populate virtual pages for all PDF pages
      final pages = List.generate(
        totalPages,
        (i) => PageModel(
          id: '${id}_p$i',
          pageIndex: i,
          pdfPageIndex: i,
        ),
      );

      // Create PDF notebook with virtualized pages and permanent file path
      final notebook = NotebookModel(
        id: id,
        title: title,
        folderId: _selectedFolderId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        coverColor: 0xFFDC2626, // Red cover for PDFs
        sourcePdfPath: permanentPdfPath,
        pdfTotalPages: totalPages,
        pages: pages,
      );

      _notebooks.insert(0, notebook);
      await _storage.saveNotebook(notebook);
      notifyListeners();
      return notebook;
    } catch (e) {
      debugPrint('[LibraryState] Error importing PDF: $e');
      return null;
    }
  }

  final Map<String, NotebookEditorState> _activeEditors = {};

  NotebookEditorState getOrCreateEditor(String notebookId) {
    final existing = _activeEditors[notebookId];
    if (existing != null) {
      return existing;
    }
    final notebook = _notebooks.firstWhere(
      (n) => n.id == notebookId,
      orElse: () => NotebookModel.createNew(id: notebookId, title: 'Untitled'),
    );
    final editor = NotebookEditorState(
      notebook: notebook,
      onNotebookChanged: (updated) => syncNotebookInMemory(updated),
    );
    _activeEditors[notebookId] = editor;
    return editor;
  }

  void releaseEditor(String notebookId) {
    final editor = _activeEditors.remove(notebookId);
    if (editor != null) {
      final pdfPath = editor.notebook.sourcePdfPath;
      if (pdfPath != null && pdfPath.isNotEmpty) {
        PdfVirtualCache().clearForPdf(pdfPath);
      }
      editor.dispose();
    } else {
      final nb = _notebooks.where((n) => n.id == notebookId).firstOrNull;
      if (nb?.sourcePdfPath != null) {
        PdfVirtualCache().clearForPdf(nb!.sourcePdfPath!);
      }
    }
  }

  void syncNotebookInMemory(NotebookModel updated) {
    final index = _notebooks.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notebooks[index] = updated;
      notifyListeners();
    }
  }

  Future<void> updateNotebook(NotebookModel updated) async {
    final index = _notebooks.indexWhere((n) => n.id == updated.id);
    if (index != -1) {
      _notebooks[index] = updated;
      _activeEditors[updated.id]?.syncNotebook(updated);
      await _storage.saveNotebook(updated);
      notifyListeners();
    }
  }

  Future<void> moveToTrash(String notebookId) async {
    final index = _notebooks.indexWhere((n) => n.id == notebookId);
    if (index != -1) {
      final updated = _notebooks[index].copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
      );
      _notebooks[index] = updated;
      _activeEditors[notebookId]?.syncNotebook(updated);
      await _storage.saveNotebook(updated);
      notifyListeners();
    }
  }

  Future<void> restoreFromTrash(String notebookId) async {
    final index = _notebooks.indexWhere((n) => n.id == notebookId);
    if (index != -1) {
      final updated = _notebooks[index].copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );
      _notebooks[index] = updated;
      _activeEditors[notebookId]?.syncNotebook(updated);
      await _storage.saveNotebook(updated);
      notifyListeners();
    }
  }

  Future<void> deleteNotebookPermanently(String notebookId) async {
    releaseEditor(notebookId);
    _notebooks.removeWhere((n) => n.id == notebookId);
    await _storage.deleteNotebook(notebookId);
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    final toDelete = _notebooks.where((n) => n.isDeleted).map((n) => n.id).toList();
    for (final id in toDelete) {
      releaseEditor(id);
      await _storage.deleteNotebook(id);
    }
    _notebooks.removeWhere((n) => n.isDeleted);
    notifyListeners();
  }

  Future<void> renameNotebook(
    String notebookId,
    String newTitle, {
    int? coverColor,
    List<String>? tags,
  }) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    final index = _notebooks.indexWhere((n) => n.id == notebookId);
    if (index != -1) {
      final updated = _notebooks[index].copyWith(
        title: trimmed,
        coverColor: coverColor,
        tags: tags,
        updatedAt: DateTime.now(),
      );
      _notebooks[index] = updated;
      _activeEditors[notebookId]?.syncNotebook(updated);
      await _storage.saveNotebook(updated);
      notifyListeners();
    }
  }

  Future<void> togglePinNotebook(String notebookId) async {
    final index = _notebooks.indexWhere((n) => n.id == notebookId);
    if (index != -1) {
      final current = _notebooks[index];
      final updated = current.copyWith(
        isPinned: !current.isPinned,
        updatedAt: DateTime.now(),
      );
      _notebooks[index] = updated;
      _activeEditors[notebookId]?.syncNotebook(updated);
      await _storage.saveNotebook(updated);
      notifyListeners();
    }
  }

  Future<void> updateNotebookTags(String notebookId, List<String> tags) async {
    final index = _notebooks.indexWhere((n) => n.id == notebookId);
    if (index != -1) {
      final cleaned = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
      final updated = _notebooks[index].copyWith(
        tags: cleaned,
        updatedAt: DateTime.now(),
      );
      _notebooks[index] = updated;
      _activeEditors[notebookId]?.syncNotebook(updated);
      await _storage.saveNotebook(updated);
      notifyListeners();
    }
  }

  Future<void> moveNotebookToFolder(String notebookId, String? folderId) async {
    final index = _notebooks.indexWhere((n) => n.id == notebookId);
    if (index != -1) {
      final updated = _notebooks[index].copyWith(
        folderId: folderId,
        clearFolderId: folderId == null,
      );
      _notebooks[index] = updated;
      _activeEditors[notebookId]?.syncNotebook(updated);
      await _storage.saveNotebook(updated);
      notifyListeners();
    }
  }

  Future<void> deleteNotebook(String notebookId) async {
    await moveToTrash(notebookId);
  }

  // Folder Operations
  Future<void> createFolder(String name, {int colorValue = 0xFF3B82F6}) async {
    final newFolder = FolderModel(
      id: const Uuid().v4(),
      name: name,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );

    _folders.add(newFolder);
    await _storage.saveFolders(_folders);
    notifyListeners();
  }

  Future<void> renameFolder(
    String folderId,
    String newName, {
    int? colorValue,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final index = _folders.indexWhere((f) => f.id == folderId);
    if (index != -1) {
      _folders[index] = _folders[index].copyWith(
        name: trimmed,
        colorValue: colorValue,
      );
      await _storage.saveFolders(_folders);
      notifyListeners();
    }
  }

  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((f) => f.id == folderId);
    // Unassign folder from notebooks
    for (int i = 0; i < _notebooks.length; i++) {
      if (_notebooks[i].folderId == folderId) {
        _notebooks[i] = _notebooks[i].copyWith(clearFolderId: true);
        _activeEditors[_notebooks[i].id]?.syncNotebook(_notebooks[i]);
        await _storage.saveNotebook(_notebooks[i]);
      }
    }
    if (_selectedFolderId == folderId) {
      _selectedFolderId = null;
    }
    await _storage.saveFolders(_folders);
    notifyListeners();
  }

  // Google Drive Sync
  Future<void> triggerSync() async {
    final downloaded = await _googleDrive.syncAll(_notebooks);
    for (final remoteNb in downloaded) {
      final existingIndex = _notebooks.indexWhere((n) => n.id == remoteNb.id);
      if (existingIndex != -1) {
        _notebooks[existingIndex] = remoteNb;
        _activeEditors[remoteNb.id]?.syncNotebook(remoteNb);
      } else {
        _notebooks.insert(0, remoteNb);
      }
      await _storage.saveNotebook(remoteNb);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final editor in _activeEditors.values) {
      editor.dispose();
    }
    _activeEditors.clear();
    super.dispose();
  }
}
