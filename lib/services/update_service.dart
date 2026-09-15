import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  static const String currentVersion = '1.0.0';
  static const String githubOwner = 'kitsunov';
  static const String githubRepo = 'kitnote';

  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Checks GitHub Releases for new APK versions
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'KitNote-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] GitHub releases response code: ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final String tagName = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
      final String title = data['name'] as String? ?? 'Новая версия';
      final String changelog = data['body'] as String? ?? '';
      final String releaseUrl = data['html_url'] as String? ?? 'https://github.com/$githubOwner/$githubRepo/releases';

      // Find APK download asset
      String? apkUrl;
      final List? assets = data['assets'] as List?;
      if (assets != null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      if (_isVersionGreater(tagName, currentVersion)) {
        return UpdateInfo(
          tagName: tagName,
          title: title,
          changelog: changelog,
          releaseUrl: releaseUrl,
          apkDownloadUrl: apkUrl,
        );
      }

      return null;
    } catch (e) {
      debugPrint('[UpdateService] Error checking for updates: $e');
      return null;
    }
  }

  /// Compare semver version strings (e.g. 1.0.1 > 1.0.0)
  bool _isVersionGreater(String remote, String local) {
    try {
      final rParts = remote.split('.').map(int.parse).toList();
      final lParts = local.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (e) {
      return remote != local;
    }
  }

  /// Show interactive update dialog
  static void showUpdateDialog(BuildContext context, UpdateInfo info) {
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
                  const Text('Доступно обновление', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Версия v${info.tagName}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                  const Text('Что нового:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                const Text(
                  'Вы можете скачать APK напрямую или перейти на страницу релиза GitHub.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Позже'),
          ),
          OutlinedButton(
            onPressed: () async {
              final uri = Uri.parse(info.releaseUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Открыть GitHub'),
          ),
          if (info.apkDownloadUrl != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Скачать APK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final uri = Uri.parse(info.apkDownloadUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
    );
  }
}
