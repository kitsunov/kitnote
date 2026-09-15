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

  Future<Directory> get pdfsDir async {
    final base = await baseDir;
    final dir = Directory('${base.path}/pdfs');
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
          // Attempt automatic recovery from .bak file if available
          final bakFile = File('${file.path}.bak');
          if (await bakFile.exists()) {
            try {
              final bakContent = await bakFile.readAsString();
              final bakJson = jsonDecode(bakContent);
              notebooks.add(NotebookModel.fromJson(bakJson as Map<String, dynamic>));
              debugPrint('[StorageService] Successfully recovered notebook from backup: ${bakFile.path}');
            } catch (bakErr) {
              debugPrint('[StorageService] Failed to recover from backup: $bakErr');
            }
          }
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

  final Map<String, Future<bool>> _saveQueues = {};

  Future<bool> saveNotebook(NotebookModel notebook) {
    final previous = _saveQueues[notebook.id] ?? Future.value(true);
    final task = previous.then((_) => _atomicSaveNotebook(notebook));
    _saveQueues[notebook.id] = task;
    return task;
  }

  Future<bool> _atomicSaveNotebook(NotebookModel notebook) async {
    try {
      final dir = await notebooksDir;
      final targetFile = File('${dir.path}/${notebook.id}.json');
      final tempFile = File('${dir.path}/${notebook.id}.json.tmp');
      final backupFile = File('${dir.path}/${notebook.id}.json.bak');

      final jsonStr = jsonEncode(notebook.toJson());
      await tempFile.writeAsString(jsonStr, flush: true);

      // Create backup copy of previous valid file
      if (await targetFile.exists()) {
        try {
          await targetFile.copy(backupFile.path);
        } catch (_) {}
      }

      // Atomic rename with copy fallback
      try {
        await tempFile.rename(targetFile.path);
      } catch (_) {
        await tempFile.copy(targetFile.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
      return true;
    } catch (e) {
      debugPrint('[StorageService] Error saving notebook ${notebook.id}: $e');
      return false;
    }
  }

  Future<void> deleteNotebook(String notebookId) async {
    try {
      final dir = await notebooksDir;
      final file = File('${dir.path}/$notebookId.json');
      if (await file.exists()) {
        await file.delete();
      }
      final bakFile = File('${dir.path}/$notebookId.json.bak');
      if (await bakFile.exists()) {
        await bakFile.delete();
      }
      final tmpFile = File('${dir.path}/$notebookId.json.tmp');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      final pdfDir = await pdfsDir;
      final pdfFile = File('${pdfDir.path}/$notebookId.pdf');
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    } catch (e) {
      debugPrint('[StorageService] Error deleting notebook $notebookId: $e');
    }
  }
}
