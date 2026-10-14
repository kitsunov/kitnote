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

  static Directory? overrideBaseDir;
  Directory? _baseDir;

  Future<Directory> get baseDir async {
    final override = overrideBaseDir;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }
    final cached = _baseDir;
    if (cached != null && await cached.exists()) return cached;
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

  Future<Directory> get imagesDir async {
    final base = await baseDir;
    final dir = Directory('${base.path}/images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Sanitizes an ID to prevent directory traversal attacks
  static String sanitizeId(String id) {
    final sanitized = id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    return sanitized.isNotEmpty ? sanitized : 'default_id';
  }

  /// Copies an image file from temporary picker cache into permanent app storage
  Future<String> copyImageToPermanentStorage(
    String sourcePath,
    String notebookId,
    String imageId,
  ) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return sourcePath;
      }
      final imgDir = await imagesDir;
      final safeNbId = sanitizeId(notebookId);
      final safeImgId = sanitizeId(imageId);
      final dotIndex = sourcePath.lastIndexOf('.');
      String ext = 'png';
      if (dotIndex != -1 && dotIndex < sourcePath.length - 1) {
        final rawExt = sourcePath.substring(dotIndex + 1).toLowerCase();
        final cleanExt = rawExt.replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (cleanExt.isNotEmpty && cleanExt.length <= 5) {
          ext = cleanExt;
        }
      }
      final targetPath = '${imgDir.path}/${safeNbId}_$safeImgId.$ext';
      if (sourceFile.path != targetPath) {
        await sourceFile.copy(targetPath);
      }
      return targetPath;
    } catch (e) {
      debugPrint('[StorageService] Error copying image to permanent storage: $e');
      return sourcePath;
    }
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

  static String _encodeNotebookIsolate(Map<String, dynamic> jsonMap) {
    return jsonEncode(jsonMap);
  }

  static Map<String, dynamic> _decodeNotebookIsolate(String content) {
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<NotebookModel?> _loadSingleNotebookFile(File file) async {
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> json = content.length > 65536
          ? await compute(_decodeNotebookIsolate, content)
          : jsonDecode(content) as Map<String, dynamic>;
      return NotebookModel.fromJson(json);
    } catch (e) {
      debugPrint('[StorageService] Error reading notebook file ${file.path}: $e');
      // Attempt automatic recovery from .bak file if available
      final bakFile = File('${file.path}.bak');
      if (await bakFile.exists()) {
        try {
          final bakContent = await bakFile.readAsString();
          final Map<String, dynamic> bakJson = bakContent.length > 65536
              ? await compute(_decodeNotebookIsolate, bakContent)
              : jsonDecode(bakContent) as Map<String, dynamic>;
          debugPrint('[StorageService] Successfully recovered notebook from backup: ${bakFile.path}');
          return NotebookModel.fromJson(bakJson);
        } catch (bakErr) {
          debugPrint('[StorageService] Failed to recover from backup: $bakErr');
        }
      }
      return null;
    }
  }

  // Notebooks Storage (parallelized + isolate decoding for large files)
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

      final loaded = await Future.wait(files.map(_loadSingleNotebookFile));
      final notebooks = loaded.whereType<NotebookModel>().toList();

      // Sort recently updated first
      notebooks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notebooks;
    } catch (e) {
      debugPrint('[StorageService] Error loading notebooks: $e');
      return [];
    }
  }

  final Map<String, Future<bool>> _saveQueues = {};
  final Set<String> _deletedNotebookIds = {};

  Future<bool> saveNotebook(NotebookModel notebook) {
    final safeId = sanitizeId(notebook.id);
    if (_deletedNotebookIds.contains(safeId)) {
      return Future.value(false);
    }
    final previous = _saveQueues[safeId] ?? Future.value(true);
    final task = previous.then((_) => _atomicSaveNotebook(notebook));
    _saveQueues[safeId] = task;
    return task;
  }

  Future<bool> _atomicSaveNotebook(NotebookModel notebook) async {
    final safeId = sanitizeId(notebook.id);
    if (_deletedNotebookIds.contains(safeId)) {
      return false;
    }
    try {
      final dir = await notebooksDir;
      final targetFile = File('${dir.path}/$safeId.json');
      final tempFile = File('${dir.path}/$safeId.json.tmp');
      final backupFile = File('${dir.path}/$safeId.json.bak');

      final jsonMap = notebook.toJson();
      int totalPoints = 0;
      for (final p in notebook.pages) {
        for (final s in p.strokes) {
          totalPoints += s.points.length;
        }
      }
      final String jsonStr = totalPoints > 500
          ? await compute(_encodeNotebookIsolate, jsonMap)
          : jsonEncode(jsonMap);
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

  /// Exports a full editable `.kitnote` backup archive (gzipped JSON bundle containing
  /// notebook metadata, pages, strokes, text, embedded images, and background PDF).
  Future<File?> exportKitNoteBackup(
    NotebookModel notebook, {
    String? targetFilePath,
  }) async {
    try {
      String? pdfBase64;
      if (notebook.sourcePdfPath != null) {
        final pdfFile = File(notebook.sourcePdfPath!);
        if (await pdfFile.exists()) {
          pdfBase64 = base64Encode(await pdfFile.readAsBytes());
        }
      }

      final Map<String, Map<String, String>> imagesBundle = {};
      for (final page in notebook.pages) {
        for (final img in page.imageElements) {
          if (img.rawBytes != null) {
            imagesBundle[img.id] = {
              'ext': 'png',
              'data': base64Encode(img.rawBytes!),
            };
          } else if (img.localPath != null) {
            final imgFile = File(img.localPath!);
            if (await imgFile.exists()) {
              final dotIdx = img.localPath!.lastIndexOf('.');
              final ext = (dotIdx != -1 && dotIdx < img.localPath!.length - 1)
                  ? img.localPath!.substring(dotIdx + 1).toLowerCase()
                  : 'png';
              imagesBundle[img.id] = {
                'ext': ext,
                'data': base64Encode(await imgFile.readAsBytes()),
              };
            }
          }
        }
      }

      final bundle = <String, dynamic>{
        'format': 'kitnote_backup_v1',
        'exportedAt': DateTime.now().toIso8601String(),
        'notebook': notebook.toJson(),
        if (pdfBase64 != null) 'pdfBase64': pdfBase64,
        if (imagesBundle.isNotEmpty) 'images': imagesBundle,
      };

      final jsonBytes = utf8.encode(jsonEncode(bundle));
      final compressedBytes = gzip.encode(jsonBytes);

      final File outFile;
      if (targetFilePath != null) {
        outFile = File(targetFilePath);
      } else {
        final base = await baseDir;
        final safeTitle = notebook.title
            .replaceAll(RegExp(r'[^\w\s\-\u0400-\u04FF]'), '')
            .trim()
            .replaceAll(RegExp(r'\s+'), '_');
        final fileName = safeTitle.isNotEmpty ? safeTitle : sanitizeId(notebook.id);
        outFile = File('${base.path}/${fileName}_backup.kitnote');
      }

      await outFile.writeAsBytes(compressedBytes, flush: true);
      return outFile;
    } catch (e) {
      debugPrint('[StorageService] Error exporting .kitnote backup: $e');
      return null;
    }
  }

  /// Imports a `.kitnote` backup file, restoring its PDF, images, and editable pages/strokes.
  Future<NotebookModel?> importKitNoteBackup(
    String backupFilePath, {
    String? newNotebookId,
  }) async {
    try {
      final file = File(backupFilePath);
      if (!await file.exists()) return null;

      final rawBytes = await file.readAsBytes();
      String jsonStr;
      try {
        jsonStr = utf8.decode(gzip.decode(rawBytes));
      } catch (_) {
        jsonStr = utf8.decode(rawBytes);
      }

      final Map<String, dynamic> bundle = jsonDecode(jsonStr) as Map<String, dynamic>;
      final Map<String, dynamic> notebookJson = bundle.containsKey('notebook')
          ? Map<String, dynamic>.from(bundle['notebook'] as Map)
          : bundle;

      var notebook = NotebookModel.fromJson(notebookJson);
      final targetNbId = sanitizeId(newNotebookId ?? notebook.id);

      // Restore background PDF if bundled
      String? restoredPdfPath = notebook.sourcePdfPath;
      if (bundle['pdfBase64'] is String) {
        final pdfBytes = base64Decode(bundle['pdfBase64'] as String);
        final pdfDir = await pdfsDir;
        final pdfFile = File('${pdfDir.path}/$targetNbId.pdf');
        await pdfFile.writeAsBytes(pdfBytes, flush: true);
        restoredPdfPath = pdfFile.path;
      }

      // Restore bundled images
      final Map<String, String> restoredImagePaths = {};
      if (bundle['images'] is Map) {
        final imgMap = bundle['images'] as Map;
        final imgDir = await imagesDir;
        for (final entry in imgMap.entries) {
          final imgId = sanitizeId(entry.key.toString());
          final val = entry.value;
          if (val is Map && val['data'] is String) {
            final rawExt = (val['ext']?.toString() ?? 'png').replaceAll(RegExp(r'[^a-z0-9]'), '');
            final ext = rawExt.isNotEmpty && rawExt.length <= 5 ? rawExt : 'png';
            final imgBytes = base64Decode(val['data'] as String);
            final imgFile = File('${imgDir.path}/${targetNbId}_$imgId.$ext');
            await imgFile.writeAsBytes(imgBytes, flush: true);
            restoredImagePaths[entry.key.toString()] = imgFile.path;
          }
        }
      }

      final updatedPages = notebook.pages.map((page) {
        if (restoredImagePaths.isEmpty) return page;
        final updatedImages = page.imageElements.map((img) {
          final newPath = restoredImagePaths[img.id];
          return newPath != null ? img.copyWith(localPath: newPath) : img;
        }).toList();
        return page.copyWith(imageElements: updatedImages);
      }).toList();

      notebook = notebook.copyWith(
        id: targetNbId,
        sourcePdfPath: restoredPdfPath,
        pages: updatedPages,
        updatedAt: DateTime.now(),
      );

      await saveNotebook(notebook);
      return notebook;
    } catch (e) {
      debugPrint('[StorageService] Error importing .kitnote backup: $e');
      return null;
    }
  }

  Future<void> deleteNotebook(String notebookId) async {
    final safeId = sanitizeId(notebookId);
    _deletedNotebookIds.add(safeId);
    final previous = _saveQueues[safeId] ?? Future.value(true);
    final task = previous.then((_) => _deleteNotebookFiles(safeId));
    _saveQueues[safeId] = task;
    try {
      await task;
    } finally {
      _deletedNotebookIds.remove(safeId);
    }
  }

  Future<bool> _deleteNotebookFiles(String safeId) async {
    try {
      final dir = await notebooksDir;
      final file = File('${dir.path}/$safeId.json');
      if (await file.exists()) {
        await file.delete();
      }
      final bakFile = File('${dir.path}/$safeId.json.bak');
      if (await bakFile.exists()) {
        await bakFile.delete();
      }
      final tmpFile = File('${dir.path}/$safeId.json.tmp');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
      final pdfDir = await pdfsDir;
      final pdfFile = File('${pdfDir.path}/$safeId.pdf');
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
      final imgDir = await imagesDir;
      if (await imgDir.exists()) {
        final prefix = '${safeId}_';
        for (final entity in imgDir.listSync().whereType<File>()) {
          final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : '';
          if (name.startsWith(prefix)) {
            await entity.delete();
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('[StorageService] Error deleting notebook $safeId: $e');
      return false;
    }
  }
}
