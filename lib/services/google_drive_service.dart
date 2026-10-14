import 'dart:async';
import 'dart:convert';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../models/notebook_model.dart';

enum SyncStatus {
  disconnected,
  idle,
  syncing,
  success,
  error,
}

class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      drive.DriveApi.driveFileScope,
    ],
  );

  StreamSubscription<GoogleSignInAccount?>? _authSubscription;
  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;
  SyncStatus _status = SyncStatus.disconnected;
  String? _lastError;
  DateTime? _lastSyncTime;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;

  Future<void> init() async {
    await _authSubscription?.cancel();
    _authSubscription = _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      _currentUser = account;
      if (account != null) {
        final authClient = await _googleSignIn.authenticatedClient();
        if (authClient != null) {
          _driveApi = drive.DriveApi(authClient);
          _status = SyncStatus.idle;
        }
      } else {
        _driveApi = null;
        _status = SyncStatus.disconnected;
      }
      notifyListeners();
    });

    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('[GoogleDriveService] Silent sign-in error: $e');
    }
  }

  Future<bool> signIn() async {
    try {
      _status = SyncStatus.syncing;
      notifyListeners();

      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        final authClient = await _googleSignIn.authenticatedClient();
        if (authClient != null) {
          _driveApi = drive.DriveApi(authClient);
          _status = SyncStatus.idle;
          notifyListeners();
          return true;
        }
      }
      _status = SyncStatus.disconnected;
      notifyListeners();
      return false;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
    _status = SyncStatus.disconnected;
    notifyListeners();
  }

  /// Synchronize local and remote notebooks on Google Drive (two-way pull & push).
  /// Returns any notebooks that were downloaded or updated from Google Drive.
  Future<List<NotebookModel>> syncAll(List<NotebookModel> localNotebooks) async {
    if (_driveApi == null || !isSignedIn) {
      _lastError = 'Не выполнен вход в Google Drive';
      notifyListeners();
      return const [];
    }

    _status = SyncStatus.syncing;
    notifyListeners();

    final downloadedNotebooks = <NotebookModel>[];

    try {
      final folderId = await _getOrCreateAppFolder();

      // List all existing notebook JSON files in the app folder on Drive
      final remoteList = await _driveApi!.files.list(
        q: "'$folderId' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, modifiedTime)',
      );

      final remoteFilesByName = <String, drive.File>{};
      for (final f in remoteList.files ?? const <drive.File>[]) {
        if (f.name != null && f.id != null) {
          remoteFilesByName[f.name!] = f;
        }
      }

      final localById = <String, NotebookModel>{
        for (final nb in localNotebooks) nb.id: nb,
      };

      // 1. Upload or merge local notebooks
      for (final notebook in localNotebooks) {
        final filename = 'kitnote_${notebook.id}.json';
        final existingRemote = remoteFilesByName.remove(filename);

        if (existingRemote != null && existingRemote.id != null) {
          final remoteModified = existingRemote.modifiedTime;
          if (remoteModified != null && remoteModified.isAfter(notebook.updatedAt.toUtc())) {
            final remoteNb = await _downloadNotebookFile(existingRemote.id!);
            if (remoteNb != null && remoteNb.updatedAt.isAfter(notebook.updatedAt)) {
              downloadedNotebooks.add(remoteNb);
              continue;
            }
          }

          final jsonBytes = utf8.encode(jsonEncode(notebook.toJson()));
          final media = drive.Media(Stream.value(jsonBytes), jsonBytes.length);
          await _driveApi!.files.update(
            drive.File(),
            existingRemote.id!,
            uploadMedia: media,
          );
        } else {
          final jsonBytes = utf8.encode(jsonEncode(notebook.toJson()));
          final media = drive.Media(Stream.value(jsonBytes), jsonBytes.length);
          final fileMetadata = drive.File()
            ..name = filename
            ..parents = [folderId]
            ..mimeType = 'application/json';

          await _driveApi!.files.create(
            fileMetadata,
            uploadMedia: media,
          );
        }
      }

      // 2. Pull any remote notebooks that do not exist locally
      for (final entry in remoteFilesByName.entries) {
        final name = entry.key;
        final file = entry.value;
        if (!name.startsWith('kitnote_') || !name.endsWith('.json') || file.id == null) {
          continue;
        }
        final remoteNb = await _downloadNotebookFile(file.id!);
        if (remoteNb != null && !localById.containsKey(remoteNb.id)) {
          downloadedNotebooks.add(remoteNb);
        }
      }

      _lastSyncTime = DateTime.now();
      _status = SyncStatus.success;
      _lastError = null;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      debugPrint('[GoogleDriveService] Sync error: $e');
    }

    notifyListeners();
    return downloadedNotebooks;
  }

  Future<NotebookModel?> _downloadNotebookFile(String fileId) async {
    try {
      final response = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (response is drive.Media) {
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
        }
        final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        return NotebookModel.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[GoogleDriveService] Failed to download remote notebook $fileId: $e');
    }
    return null;
  }

  Future<String> _getOrCreateAppFolder() async {
    const folderName = 'KitNote_Notebooks';
    const query = "mimeType = 'application/vnd.google-apps.folder' and name = '$folderName' and trashed = false";
    final result = await _driveApi!.files.list(q: query, spaces: 'drive', $fields: 'files(id, name)');

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }

    // Create folder
    final folderMetadata = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _driveApi!.files.create(folderMetadata, $fields: 'id');
    return created.id!;
  }
}
