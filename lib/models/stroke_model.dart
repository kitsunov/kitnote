import 'dart:ui';
import 'point_model.dart';
import 'tool_type.dart';

class StrokeModel {
  final String id;
  final List<Point2D> points;
  final int colorValue;
  final double strokeWidth;
  final double opacity;
  final ToolType toolType;

  const StrokeModel({
    required this.id,
    required this.points,
    required this.colorValue,
    required this.strokeWidth,
    this.opacity = 1.0,
    required this.toolType,
  });

  Color get color => Color(colorValue).withValues(alpha: opacity);

  Rect get boundingBox {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final pad = strokeWidth / 2;
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  StrokeModel copyWith({
    String? id,
    List<Point2D>? points,
    int? colorValue,
    double? strokeWidth,
    double? opacity,
    ToolType? toolType,
  }) {
    return StrokeModel(
      id: id ?? this.id,
      points: points ?? this.points,
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      toolType: toolType ?? this.toolType,
    );
  }

  StrokeModel translate(double dx, double dy) {
    return copyWith(
      points: points.map((p) => p.translate(dx, dy)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pts': points.map((p) => p.toJson()).toList(),
    'c': colorValue,
    'w': strokeWidth,
    'o': opacity,
    't': toolType.index,
  };

  factory StrokeModel.fromJson(Map<String, dynamic> json) => StrokeModel(
    id: json['id'] as String,
    points: (json['pts'] as List)
        .map((p) => Point2D.fromJson(p as Map<String, dynamic>))
        .toList(),
    colorValue: json['c'] as int,
    strokeWidth: (json['w'] as num).toDouble(),
    opacity: (json['o'] as num?)?.toDouble() ?? 1.0,
    toolType: ToolType.values[json['t'] as int? ?? 0],
  );
}
