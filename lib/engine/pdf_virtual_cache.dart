import 'dart:collection';
import 'package:flutter/foundation.dart';

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

  void clearForPdf(String pdfPath) {
    _cache.removeWhere((key, _) => key.startsWith(pdfPath));
    _pendingRenders.removeWhere((key) => key.startsWith(pdfPath));
  }

  void clearAll() {
    _cache.clear();
    _pendingRenders.clear();
  }
}
