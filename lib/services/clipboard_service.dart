import 'package:flutter/foundation.dart';
import '../models/image_element_model.dart';
import '../models/stroke_model.dart';
import '../models/text_element_model.dart';

class ClipboardPayload {
  final List<StrokeModel> strokes;
  final List<TextElementModel> textElements;
  final List<ImageElementModel> imageElements;

  const ClipboardPayload({
    this.strokes = const [],
    this.textElements = const [],
    this.imageElements = const [],
  });

  bool get isEmpty =>
      strokes.isEmpty && textElements.isEmpty && imageElements.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get totalCount =>
      strokes.length + textElements.length + imageElements.length;
}

/// Application-wide clipboard singleton allowing users to copy/cut/paste
/// strokes, text boxes, and images across pages and across split-screen notebooks.
class ClipboardService extends ChangeNotifier {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  ClipboardPayload _payload = const ClipboardPayload();

  ClipboardPayload get payload => _payload;
  bool get hasContent => _payload.isNotEmpty;

  void copy({
    List<StrokeModel> strokes = const [],
    List<TextElementModel> textElements = const [],
    List<ImageElementModel> imageElements = const [],
  }) {
    _payload = ClipboardPayload(
      strokes: List.unmodifiable(strokes),
      textElements: List.unmodifiable(textElements),
      imageElements: List.unmodifiable(imageElements),
    );
    notifyListeners();
  }

  void clear() {
    _payload = const ClipboardPayload();
    notifyListeners();
  }
}
