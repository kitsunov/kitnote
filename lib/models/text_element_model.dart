import 'dart:ui';

class TextElementModel {
  final String id;
  final String text;
  final double x;
  final double y;
  final double width;
  final double height;
  final double fontSize;
  final int colorValue;
  final bool isBold;
  final bool isItalic;

  const TextElementModel({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    this.width = 240,
    this.height = 80,
    this.fontSize = 18.0,
    this.colorValue = 0xFF1E293B,
    this.isBold = false,
    this.isItalic = false,
  });

  Color get color => Color(colorValue);
  Rect get boundingBox => Rect.fromLTWH(x, y, width, height);

  TextElementModel copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    double? width,
    double? height,
    double? fontSize,
    int? colorValue,
    bool? isBold,
    bool? isItalic,
  }) {
    return TextElementModel(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      fontSize: fontSize ?? this.fontSize,
      colorValue: colorValue ?? this.colorValue,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
    );
  }

  TextElementModel translate(double dx, double dy) {
    return copyWith(x: x + dx, y: y + dy);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'txt': text,
    'x': x,
    'y': y,
    'w': width,
    'h': height,
    'fs': fontSize,
    'c': colorValue,
    'b': isBold,
    'i': isItalic,
  };

  factory TextElementModel.fromJson(Map<String, dynamic> json) =>
      TextElementModel(
        id: json['id'] as String,
        text: json['txt'] as String? ?? '',
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        width: (json['w'] as num?)?.toDouble() ?? 240,
        height: (json['h'] as num?)?.toDouble() ?? 80,
        fontSize: (json['fs'] as num?)?.toDouble() ?? 18.0,
        colorValue: json['c'] as int? ?? 0xFF1E293B,
        isBold: json['b'] as bool? ?? false,
        isItalic: json['i'] as bool? ?? false,
      );
}
