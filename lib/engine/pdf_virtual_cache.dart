import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

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
    try {
      final docBytes = await _loadDocBytes(request.pdfPath);
      if (docBytes == null || docBytes.isEmpty) {
        debugPrint('[PdfVirtualCache] PDF file not found or empty: ${request.pdfPath}');
        return null;
      }

      await for (final raster in Printing.raster(docBytes, pages: [request.pageIndex], dpi: request.scale)) {
        final pngBytes = await raster.toPng();
        putPage(request, pngBytes);
        return pngBytes;
      }
    } catch (e) {
      debugPrint('[PdfVirtualCache] Error rendering page ${request.pageIndex} of ${request.pdfPath}: $e');
    } finally {
      _inFlightRenders.remove(request.cacheKey);
    }
    return null;
  }

  /// Fast scanner that inspects PDF binary bytes for the total page count with multi-strategy fallbacks
  static int getPdfPageCountFromBytes(Uint8List bytes) {
    try {
      int maxCount = 0;
      final len = bytes.length;
      final countTarget = [47, 67, 111, 117, 110, 116]; // '/Count'

      // Strategy 1: Scan for /Count integers in page dictionary
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
          if (hasDigit && num > maxCount) {
            maxCount = num;
          }
          i = k;
        }
      }

      if (maxCount > 0) {
        return maxCount;
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
