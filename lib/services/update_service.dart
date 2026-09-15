import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/l10n/app_localizations.dart';

class UpdateInfo {
  final String tagName;
  final String title;
  final String changelog;
  final String releaseUrl;
  final String? apkDownloadUrl;

  const UpdateInfo({
    required this.tagName,
    required this.title,
    required this.changelog,
    required this.releaseUrl,
    this.apkDownloadUrl,
  });
}

class UpdateService {
  static const String currentVersion = '1.0.6';
  static const String githubOwner = 'kitsunov';
  static const String githubRepo = 'kitnote';
  static const MethodChannel _channel = MethodChannel('com.kitnote.app/updater');

  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Checks GitHub releases for latest release
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest');
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'KitNote-App/$currentVersion',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final String rawTag = data['tag_name'] as String? ?? '';
      final String latestTag = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;

      if (_isVersionNewer(latestTag, currentVersion)) {
        final List<dynamic> assets = data['assets'] as List<dynamic>? ?? [];
        String? apkUrl;
        for (final asset in assets) {
          final name = (asset['name'] as String? ?? '').toLowerCase();
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }

        final String title = data['name'] as String? ?? 'Новая версия';
        final String changelog = data['body'] as String? ?? '';
        final String releaseUrl = data['html_url'] as String? ?? 'https://github.com/$githubOwner/$githubRepo/releases';

        return UpdateInfo(
          tagName: latestTag,
          title: title,
          changelog: changelog,
          releaseUrl: releaseUrl,
          apkDownloadUrl: apkUrl,
        );
      }
      return null;
    } catch (e) {
      debugPrint('KitNote update check failed: $e');
      return null;
    }
  }

  static bool _isVersionNewer(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Downloads APK directly inside app and triggers native Android package installer
  static Future<void> downloadAndInstall(BuildContext context, String apkUrl) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0.0);
    final ValueNotifier<String> statusNotifier = ValueNotifier<String>('Preparing...');
    final strings = AppLocalizations.of(context).strings;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.downloading, color: Colors.blue, size: 24),
            const SizedBox(width: 10),
            Text(strings.downloadUpdate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, status, _) => Text(
                status,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) => Column(
                children: [
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      progress > 0 ? '${(progress * 100).toInt()}%' : '',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final uri = Uri.parse(apkUrl);
      final remoteFileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'KitNote-v$currentVersion.apk';
      final fileName = remoteFileName.toLowerCase().endsWith('.apk') ? remoteFileName : 'KitNote-v$currentVersion.apk';
      final file = File('${tempDir.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in response.stream) {
        downloaded += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          progressNotifier.value = downloaded / contentLength;
          final downloadedMB = (downloaded / (1024 * 1024)).toStringAsFixed(1);
          final totalMB = (contentLength / (1024 * 1024)).toStringAsFixed(1);
          statusNotifier.value = 'Загрузка: $downloadedMB МБ из $totalMB МБ';
        }
      }

      await sink.flush();
      await sink.close();

      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
      }

      statusNotifier.value = 'Запуск установщика...';

      // Trigger native package installer
      if (Platform.isAndroid) {
        await _channel.invokeMethod('installApk', {'filePath': file.path});
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e')),
        );
      }
    }
  }

  /// Show interactive update dialog
  static void showUpdateDialog(BuildContext context, UpdateInfo info) {
    final strings = AppLocalizations.of(context).strings;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.system_update_alt, color: Colors.blue.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(strings.updateAvailable, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('v${info.tagName}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (info.changelog.isNotEmpty) ...[
                  Text(strings.whatsNew, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      info.changelog,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.later),
          ),
          OutlinedButton(
            onPressed: () async {
              final uri = Uri.parse(info.releaseUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('GitHub'),
          ),
          if (info.apkDownloadUrl != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: Text(strings.updateNow),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                downloadAndInstall(context, info.apkDownloadUrl!);
              },
            ),
        ],
      ),
    );
  }
}
