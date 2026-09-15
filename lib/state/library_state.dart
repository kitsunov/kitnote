import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../engine/pdf_virtual_cache.dart';
import '../models/folder_model.dart';
import '../models/notebook_model.dart';
import '../models/page_model.dart';
import '../models/page_template_model.dart';
import '../services/google_drive_service.dart';
import '../services/storage_service.dart';
import 'notebook_editor_state.dart';

class LibraryState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final GoogleDriveService _googleDrive = GoogleDriveService();

  List<NotebookModel> _notebooks = [];
  List<FolderModel> _folders = [];
  String? _selectedFolderId;
  String _searchQuery = '';
  bool _isLoading = false;

  List<NotebookModel> get notebooks => _notebooks;
  List<FolderModel> get folders => _folders;
  String? get selectedFolderId => _selectedFolderId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  GoogleDriveService get googleDrive => _googleDrive;

  LibraryState() {
    init();
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
    _selectedFolderId = folderId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<NotebookModel> get filteredNotebooks {
    return _notebooks.where((nb) {
      if (_selectedFolderId != null && nb.folderId != _selectedFolderId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = nb.title.toLowerCase().contains(query);
        final matchesTag = nb.tags.any((t) => t.toLowerCase().contains(query));
        return matchesTitle || matchesTag;
      }
      return true;
    }).toList();
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

  /// Import a PDF file and create a dedicated annotation notebook for it
  Future<NotebookModel?> importPdfNotebook() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      final name = result.files.single.name;
      final rawBytes = result.files.single.bytes;
      if (path == null && rawBytes == null) return null;

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
        final bytes = await targetFile.readAsBytes();
        totalPages = PdfVirtualCache.getPdfPageCountFromBytes(bytes);
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

  Future<void> deleteNotebook(String notebookId) async {
    _activeEditors.remove(notebookId)?.dispose();
    _notebooks.removeWhere((n) => n.id == notebookId);
    await _storage.deleteNotebook(notebookId);
    notifyListeners();
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
    await _googleDrive.syncAll(_notebooks);
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
