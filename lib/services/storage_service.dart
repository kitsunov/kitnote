import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/folder_model.dart';
import '../models/notebook_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Directory? _baseDir;

  Future<Directory> get baseDir async {
    if (_baseDir != null) return _baseDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final kitNoteDir = Directory('${appDir.path}/kitnote_data');
    if (!await kitNoteDir.exists()) {
      await kitNoteDir.create(recursive: true);
    }
    _baseDir = kitNoteDir;
    return _baseDir!;
  }

  Future<Directory> get notebooksDir async {
    final base = await baseDir;
    final dir = Directory('${base.path}/notebooks');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _foldersFile async {
    final base = await baseDir;
    return File('${base.path}/folders.json');
  }

  // Folders Storage
  Future<List<FolderModel>> loadFolders() async {
    try {
      final file = await _foldersFile;
      if (!await file.exists()) {
        // Return default folders
        final defaultFolders = [
          FolderModel(
            id: 'folder_study',
            name: 'Учеба и лекции',
            colorValue: 0xFF3B82F6,
            createdAt: DateTime.now(),
          ),
          FolderModel(
            id: 'folder_work',
            name: 'Работа и проекты',
            colorValue: 0xFF10B981,
            createdAt: DateTime.now(),
          ),
          FolderModel(
            id: 'folder_personal',
            name: 'Личные заметки',
            colorValue: 0xFFF59E0B,
            createdAt: DateTime.now(),
          ),
        ];
        await saveFolders(defaultFolders);
        return defaultFolders;
      }
      final jsonStr = await file.readAsString();
      final List decoded = jsonDecode(jsonStr);
      return decoded.map((e) => FolderModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[StorageService] Error loading folders: $e');
      return [];
    }
  }

  Future<void> saveFolders(List<FolderModel> folders) async {
    try {
      final file = await _foldersFile;
      final jsonStr = jsonEncode(folders.map((f) => f.toJson()).toList());
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('[StorageService] Error saving folders: $e');
    }
  }

  // Notebooks Storage
  Future<List<NotebookModel>> loadAllNotebooks() async {
    try {
      final dir = await notebooksDir;
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();

      if (files.isEmpty) {
        // Create demo starter notebook
        final starter = NotebookModel.createNew(
          id: 'starter_notes',
          title: 'Добро пожаловать в KitNote',
          folderId: 'folder_personal',
          coverColor: 0xFF2563EB,
        );
        await saveNotebook(starter);
        return [starter];
      }

      final notebooks = <NotebookModel>[];
      for (final file in files) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content);
          notebooks.add(NotebookModel.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[StorageService] Error reading notebook file ${file.path}: $e');
        }
      }
      // Sort recently updated first
      notebooks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notebooks;
    } catch (e) {
      debugPrint('[StorageService] Error loading notebooks: $e');
      return [];
    }
  }

  Future<void> saveNotebook(NotebookModel notebook) async {
    try {
      final dir = await notebooksDir;
      final file = File('${dir.path}/${notebook.id}.json');
      final jsonStr = jsonEncode(notebook.toJson());
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('[StorageService] Error saving notebook ${notebook.id}: $e');
    }
  }

  Future<void> deleteNotebook(String notebookId) async {
    try {
      final dir = await notebooksDir;
      final file = File('${dir.path}/$notebookId.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[StorageService] Error deleting notebook $notebookId: $e');
    }
  }
}
