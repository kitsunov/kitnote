import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../services/storage_service.dart';

class PdfPageRenderRequest {
  final String pdfPath;
  final int pageIndex;
  final double scale;

  const PdfPageRenderRequest({
    required this.pdfPath,
    required this.pageIndex,
    this.scale = 2.0,
  });

  String get cacheKey => '${pdfPath}_p${pageIndex}_s$scale';

  String get diskFileName {
    final pathHash = pdfPath.hashCode.toUnsigned(32).toRadixString(16);
    return 'pdf_${pathHash}_p${pageIndex}_s${scale.toInt()}.png';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPageRenderRequest &&
          other.pdfPath == pdfPath &&
          other.pageIndex == pageIndex &&
          other.scale == scale;

  @override
  int get hashCode => Object.hash(pdfPath, pageIndex, scale);
}

class PdfVirtualCache {
  static final PdfVirtualCache _instance = PdfVirtualCache._internal();
  factory PdfVirtualCache() => _instance;
  PdfVirtualCache._internal();

  // Max cached rendered page textures in memory to strictly prevent OOM on 1000+ page PDFs
  final int maxCacheSize = 12;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _inFlightRenders = {};
  final LinkedHashMap<String, Uint8List> _docBytesCache = LinkedHashMap();
  Directory? _diskCacheDir;

  // Concurrency throttling (max 2 parallel renders)
  int _activeRenders = 0;
  final Queue<void Function()> _renderQueue = Queue();

  Future<Directory?> _getDiskCacheDir() async {
    try {
      final override = StorageService.overrideBaseDir;
      if (override != null) {
        final dir = Directory('${override.path}/pdf_page_cache');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
      if (_diskCacheDir != null && await _diskCacheDir!.exists()) {
        return _diskCacheDir;
      }
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/kitnote_pdf_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _diskCacheDir = dir;
      return dir;
    } catch (_) {
      return null;
    }
  }

  Uint8List? getPage(PdfPageRenderRequest request) {
    final key = request.cacheKey;
    if (_cache.containsKey(key)) {
      // Re-insert to mark as most recently used
      final data = _cache.remove(key)!;
      _cache[key] = data;
      return data;
    }
    return null;
  }

  void putPage(PdfPageRenderRequest request, Uint8List imageBytes) {
    final key = request.cacheKey;
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxCacheSize) {
      // Evict oldest page
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      debugPrint('[PdfVirtualCache] Evicted cached page: $oldestKey');
    }
    _cache[key] = imageBytes;
  }

  Future<Uint8List?> _loadDocBytes(String pdfPath) async {
    if (_docBytesCache.containsKey(pdfPath)) {
      final bytes = _docBytesCache.remove(pdfPath)!;
      _docBytesCache[pdfPath] = bytes;
      return bytes;
    }
    final file = File(pdfPath);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (_docBytesCache.length >= 2) {
      _docBytesCache.remove(_docBytesCache.keys.first);
    }
    _docBytesCache[pdfPath] = bytes;
    return bytes;
  }

  /// Lazily rasterizes and caches a specific PDF page using native platform rendering with in-flight deduplication
  Future<Uint8List?> renderPage(
    String pdfPath,
    int pageIndex, {
    double dpi = 150.0,
  }) {
    final request = PdfPageRenderRequest(
      pdfPath: pdfPath,
      pageIndex: pageIndex,
      scale: dpi,
    );

    final cached = getPage(request);
    if (cached != null) return Future.value(cached);

    if (_inFlightRenders.containsKey(request.cacheKey)) {
      return _inFlightRenders[request.cacheKey]!;
    }

    final future = _renderPageInternal(request);
    _inFlightRenders[request.cacheKey] = future;
    return future;
  }

  Future<Uint8List?> _renderPageInternal(PdfPageRenderRequest request) async {
    // 1. Check disk cache before acquiring rasterizer slot
    try {
      final cacheDir = await _getDiskCacheDir();
      if (cacheDir != null) {
        final diskFile = File('${cacheDir.path}/${request.diskFileName}');
        if (await diskFile.exists()) {
          final diskBytes = await diskFile.readAsBytes();
          if (diskBytes.isNotEmpty) {
            putPage(request, diskBytes);
            _inFlightRenders.remove(request.cacheKey);
            return diskBytes;
          }
        }
      }
    } catch (_) {}

    if (_activeRenders >= 2) {
      final completer = Completer<void>();
      _renderQueue.add(completer.complete);
      await completer.future;
    }
    _activeRenders++;

    try {
      final docBytes = await _loadDocBytes(request.pdfPath);
      if (docBytes == null || docBytes.isEmpty) {
        debugPrint('[PdfVirtualCache] PDF file not found or empty: ${request.pdfPath}');
        return null;
      }

      await for (final raster in Printing.raster(docBytes, pages: [request.pageIndex], dpi: request.scale)) {
        final pngBytes = await raster.toPng();
        putPage(request, pngBytes);
        // Save to disk cache asynchronously
        _getDiskCacheDir().then((cacheDir) async {
          if (cacheDir != null) {
            try {
              final diskFile = File('${cacheDir.path}/${request.diskFileName}');
              await diskFile.writeAsBytes(pngBytes, flush: false);
            } catch (_) {}
          }
        });
        return pngBytes;
      }
    } catch (e) {
      debugPrint('[PdfVirtualCache] Error rendering page ${request.pageIndex} of ${request.pdfPath}: $e');
    } finally {
      _activeRenders--;
      if (_renderQueue.isNotEmpty) {
        final next = _renderQueue.removeFirst();
        next();
      }
      _inFlightRenders.remove(request.cacheKey);
    }
    return null;
  }

  static bool _sublistContains(Uint8List bytes, int start, int end, List<int> target) {
    final s = start < 0 ? 0 : start;
    final e = end > bytes.length ? bytes.length : end;
    final tLen = target.length;
    for (int i = s; i <= e - tLen; i++) {
      bool m = true;
      for (int j = 0; j < tLen; j++) {
        if (bytes[i + j] != target[j]) {
          m = false;
          break;
        }
      }
      if (m) return true;
    }
    return false;
  }

  /// Fast scanner that inspects PDF binary bytes for the total page count with multi-strategy fallbacks
  static int getPdfPageCountFromBytes(Uint8List bytes) {
    try {
      final len = bytes.length;
      final countTarget = [47, 67, 111, 117, 110, 116]; // '/Count'
      final outlinesTarget = [47, 79, 117, 116, 108, 105, 110, 101, 115]; // '/Outlines'
      final pagesTarget = [47, 80, 97, 103, 101, 115]; // '/Pages'

      int pagesCount = 0;
      int maxOtherCount = 0;

      // Strategy 1: Scan for /Count integers in page dictionary, prioritizing /Type /Pages and ignoring /Outlines
      for (int i = 0; i < len - 10; i++) {
        bool match = true;
        for (int j = 0; j < 6; j++) {
          if (bytes[i + j] != countTarget[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          int k = i + 6;
          while (k < len && (bytes[k] == 32 || bytes[k] == 9 || bytes[k] == 10 || bytes[k] == 13)) {
            k++;
          }
          int num = 0;
          bool hasDigit = false;
          while (k < len && bytes[k] >= 48 && bytes[k] <= 57) {
            hasDigit = true;
            num = num * 10 + (bytes[k] - 48);
            k++;
          }
          if (hasDigit && num > 0) {
            // Find enclosing dictionary << ... >> boundaries
            int dictStart = i;
            while (dictStart > 1 && dictStart > i - 500) {
              if (bytes[dictStart] == 60 && bytes[dictStart - 1] == 60) {
                break;
              }
              dictStart--;
            }
            int dictEnd = i;
            while (dictEnd < len - 1 && dictEnd < i + 500) {
              if (bytes[dictEnd] == 62 && bytes[dictEnd + 1] == 62) {
                break;
              }
              dictEnd++;
            }

            final isOutlines = _sublistContains(bytes, dictStart, dictEnd + 2, outlinesTarget);
            final isPages = _sublistContains(bytes, dictStart, dictEnd + 2, pagesTarget);

            if (!isOutlines && isPages) {
              if (num > pagesCount) {
                pagesCount = num;
              }
            } else if (!isOutlines) {
              if (num > maxOtherCount) {
                maxOtherCount = num;
              }
            }
          }
          i = k;
        }
      }

      if (pagesCount > 0) {
        return pagesCount;
      }
      if (maxOtherCount > 0) {
        return maxOtherCount;
      }

      // Strategy 2: Fallback scanning for /Type /Page occurrences (ignoring /Type /Pages)
      int pageTypeCount = 0;
      final typePageTarget = [47, 84, 121, 112, 101]; // '/Type'
      for (int i = 0; i < len - 16; i++) {
        bool match = true;
        for (int j = 0; j < 5; j++) {
          if (bytes[i + j] != typePageTarget[j]) {
            match = false;
            break;
          }
        }
        if (match) {
          int k = i + 5;
          while (k < len && (bytes[k] == 32 || bytes[k] == 9 || bytes[k] == 10 || bytes[k] == 13)) {
            k++;
          }
          if (k + 5 < len &&
              bytes[k] == 47 && // '/'
              bytes[k + 1] == 80 && // 'P'
              bytes[k + 2] == 97 && // 'a'
              bytes[k + 3] == 103 && // 'g'
              bytes[k + 4] == 101) { // 'e'
            // Ensure not '/Pages'
            if (k + 5 >= len || bytes[k + 5] != 115) { // 's'
              pageTypeCount++;
            }
          }
        }
      }

      if (pageTypeCount > 0) {
        return pageTypeCount;
      }

      return 1;
    } catch (e) {
      debugPrint('[PdfVirtualCache] Page count parsing error: $e');
      return 1;
    }
  }

  /// Memory-safe page count scanner that avoids loading 100MB+ PDFs into RAM at once
  static Future<int> getPdfPageCountFromFile(File file) async {
    try {
      if (!await file.exists()) return 1;
      final fileLen = await file.length();
      const maxFullReadBytes = 8 * 1024 * 1024; // 8 MB
      if (fileLen <= maxFullReadBytes) {
        final bytes = await file.readAsBytes();
        return getPdfPageCountFromBytes(bytes);
      }

      // For very large PDFs (>8MB), read head (4MB) + tail (4MB) where /Pages catalog resides
      const chunkSize = 4 * 1024 * 1024;
      final raf = await file.open(mode: FileMode.read);
      try {
        final head = await raf.read(chunkSize);
        await raf.setPosition(fileLen - chunkSize);
        final tail = await raf.read(chunkSize);
        final combined = Uint8List(head.length + tail.length);
        combined.setRange(0, head.length, head);
        combined.setRange(head.length, combined.length, tail);
        return getPdfPageCountFromBytes(combined);
      } finally {
        await raf.close();
      }
    } catch (e) {
      debugPrint('[PdfVirtualCache] File page count error: $e');
      return 1;
    }
  }

  void clearForPdf(String pdfPath) {
    _cache.removeWhere((key, _) => key.startsWith(pdfPath));
    _inFlightRenders.removeWhere((key, _) => key.startsWith(pdfPath));
    _docBytesCache.remove(pdfPath);
  }

  void clearAll() {
    _cache.clear();
    _inFlightRenders.clear();
    _docBytesCache.clear();
  }
}
