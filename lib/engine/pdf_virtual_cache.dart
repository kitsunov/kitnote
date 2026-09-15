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
  final int maxCacheSize = 6;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  final Set<String> _pendingRenders = {};

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
      debugPrint('[PdfVirtualCache] Evicted cached page: $oldestKey to free memory');
    }
    _cache[key] = imageBytes;
  }

  bool isRendering(PdfPageRenderRequest request) =>
      _pendingRenders.contains(request.cacheKey);

  void markRendering(PdfPageRenderRequest request) =>
      _pendingRenders.add(request.cacheKey);

  void clearRendering(PdfPageRenderRequest request) =>
      _pendingRenders.remove(request.cacheKey);

  /// Lazily rasterizes and caches a specific PDF page using native platform rendering
  Future<Uint8List?> renderPage(
    String pdfPath,
    int pageIndex, {
    double dpi = 150.0,
  }) async {
    final request = PdfPageRenderRequest(
      pdfPath: pdfPath,
      pageIndex: pageIndex,
      scale: dpi,
    );

    final cached = getPage(request);
    if (cached != null) return cached;

    if (isRendering(request)) {
      // Wait briefly if a render is already in flight for this exact page
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        final again = getPage(request);
        if (again != null) return again;
        if (!isRendering(request)) break;
      }
    }

    markRendering(request);
    try {
      final file = File(pdfPath);
      if (!await file.exists()) return null;

      final docBytes = await file.readAsBytes();
      await for (final raster in Printing.raster(docBytes, pages: [pageIndex], dpi: dpi)) {
        final pngBytes = await raster.toPng();
        putPage(request, pngBytes);
        return pngBytes;
      }
    } catch (e) {
      debugPrint('[PdfVirtualCache] Error rendering page $pageIndex of $pdfPath: $e');
    } finally {
      clearRendering(request);
    }
    return null;
  }

  /// Fast scanner that inspects PDF binary bytes for the total page count without heavy DOM parsing
  static int getPdfPageCountFromBytes(Uint8List bytes) {
    try {
      int maxCount = 1;
      final len = bytes.length;
      final target = [47, 67, 111, 117, 110, 116]; // '/Count'

      for (int i = 0; i < len - 10; i++) {
        bool match = true;
        for (int j = 0; j < 6; j++) {
          if (bytes[i + j] != target[j]) {
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
      return maxCount;
    } catch (e) {
      debugPrint('[PdfVirtualCache] Page count parsing error: $e');
      return 1;
    }
  }

  void clearForPdf(String pdfPath) {
    _cache.removeWhere((key, _) => key.startsWith(pdfPath));
    _pendingRenders.removeWhere((key) => key.startsWith(pdfPath));
  }

  void clearAll() {
    _cache.clear();
    _pendingRenders.clear();
  }
}
