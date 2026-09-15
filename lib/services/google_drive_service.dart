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
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
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

  /// Synchronize all local notebooks with Google Drive
  Future<void> syncAll(List<NotebookModel> localNotebooks) async {
    if (_driveApi == null || !isSignedIn) {
      _lastError = 'Не выполнен вход в Google Drive';
      notifyListeners();
      return;
    }

    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      // Find or create 'KitNote_Backups' folder on Google Drive
      final folderId = await _getOrCreateAppFolder();

      for (final notebook in localNotebooks) {
        final filename = 'kitnote_${notebook.id}.json';
        final jsonContent = jsonEncode(notebook.toJson());

        // Check if file already exists in Drive folder
        final list = await _driveApi!.files.list(
          q: "name = '$filename' and '$folderId' in parents and trashed = false",
          spaces: 'drive',
          $fields: 'files(id, name, modifiedTime)',
        );

        final media = drive.Media(
          Stream.value(utf8.encode(jsonContent)),
          utf8.encode(jsonContent).length,
        );

        if (list.files != null && list.files!.isNotEmpty) {
          // Update existing file
          final existingFileId = list.files!.first.id!;
          await _driveApi!.files.update(
            drive.File(),
            existingFileId,
            uploadMedia: media,
          );
        } else {
          // Create new file
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

      _lastSyncTime = DateTime.now();
      _status = SyncStatus.success;
      _lastError = null;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      debugPrint('[GoogleDriveService] Sync error: $e');
    }

    notifyListeners();
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
