import 'dart:math' as math;
import 'dart:ui';
import 'package:uuid/uuid.dart';
import '../../models/point_model.dart';
import '../../models/stroke_model.dart';

class GeometryUtils {
  /// Calculate shortest distance between point [p] and line segment [a]-[b]
  static double distanceToSegment(Offset p, Offset a, Offset b) {
    final l2 = (b.dx - a.dx) * (b.dx - a.dx) + (b.dy - a.dy) * (b.dy - a.dy);
    if (l2 == 0) return (p - a).distance;

    // Consider the line extending the segment, parameterized as a + t (b - a).
    // Projection falls on the segment when 0 <= t <= 1
    final t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = Offset(
      a.dx + clampedT * (b.dx - a.dx),
      a.dy + clampedT * (b.dy - a.dy),
    );
    return (p - projection).distance;
  }

  /// Check if a stroke is hit by an eraser point with given radius
  static bool isStrokeHitByPoint(StrokeModel stroke, Offset eraserPos, double radius) {
    if (stroke.points.isEmpty) return false;

    // Quick bounding box rejection test with radius padding
    final bounds = stroke.boundingBox.inflate(radius);
    if (!bounds.contains(eraserPos)) return false;

    if (stroke.points.length == 1) {
      return (stroke.points.first.toOffset() - eraserPos).distance <= radius + stroke.strokeWidth / 2;
    }

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final a = stroke.points[i].toOffset();
      final b = stroke.points[i + 1].toOffset();
      if (distanceToSegment(eraserPos, a, b) <= radius + stroke.strokeWidth / 2) {
        return true;
      }
    }
    return false;
  }

  /// Splits a stroke into sub-strokes by removing points within [radius] of [eraserPos]
  static List<StrokeModel> eraseStrokePixels(StrokeModel stroke, Offset eraserPos, double radius) {
    if (stroke.points.isEmpty) return [];

    final eraseRadius = radius + stroke.strokeWidth / 2;
    final bounds = stroke.boundingBox.inflate(eraseRadius);
    if (!bounds.contains(eraserPos)) {
      return [stroke];
    }

    // Subdivide sparse segments so erasing a line is responsive and granular
    final densePoints = <Point2D>[];
    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p0 = stroke.points[i];
      final p1 = stroke.points[i + 1];
      densePoints.add(p0);

      final dist = (p1.toOffset() - p0.toOffset()).distance;
      final step = math.max(4.0, radius / 2);
      if (dist > step) {
        final segments = (dist / step).ceil();
        for (int s = 1; s < segments; s++) {
          final t = s / segments;
          densePoints.add(Point2D(
            x: p0.x + (p1.x - p0.x) * t,
            y: p0.y + (p1.y - p0.y) * t,
            pressure: p0.pressure + (p1.pressure - p0.pressure) * t,
            timestamp: (p0.timestamp + (p1.timestamp - p0.timestamp) * t).round(),
          ));
        }
      }
    }
    if (stroke.points.isNotEmpty) {
      densePoints.add(stroke.points.last);
    }

    final chunks = <List<Point2D>>[];
    List<Point2D> currentChunk = [];

    for (final pt in densePoints) {
      final d = (pt.toOffset() - eraserPos).distance;
      if (d > eraseRadius) {
        currentChunk.add(pt);
      } else {
        if (currentChunk.length >= 2) {
          chunks.add(List.from(currentChunk));
        } else if (currentChunk.length == 1) {
          chunks.add([currentChunk[0], currentChunk[0].translate(0.1, 0.1)]);
        }
        currentChunk.clear();
      }
    }

    if (currentChunk.length >= 2) {
      chunks.add(currentChunk);
    } else if (currentChunk.length == 1 && densePoints.length <= 2) {
      chunks.add([currentChunk[0], currentChunk[0].translate(0.1, 0.1)]);
    }

    return chunks.map((pts) => StrokeModel(
      id: const Uuid().v4(),
      points: pts,
      colorValue: stroke.colorValue,
      strokeWidth: stroke.strokeWidth,
      opacity: stroke.opacity,
      toolType: stroke.toolType,
    )).toList();
  }

  /// Ray-casting algorithm to test if a point is inside a polygon
  static bool isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy) &&
          (point.dx <
              (polygon[j].dx - polygon[i].dx) *
                      (point.dy - polygon[i].dy) /
                      (polygon[j].dy - polygon[i].dy) +
                  polygon[i].dx)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// Checks if at least one point of the stroke is inside the lasso polygon
  static bool isStrokeEnclosedInPolygon(StrokeModel stroke, List<Offset> polygon) {
    if (stroke.points.isEmpty || polygon.length < 3) return false;
    
    // Quick test on bounding box center
    final center = stroke.boundingBox.center;
    if (isPointInPolygon(center, polygon)) return true;

    // Test each vertex
    for (final pt in stroke.points) {
      if (isPointInPolygon(pt.toOffset(), polygon)) return true;
    }
    return false;
  }

  /// Project a point onto a ruler line defined by [origin] and [angleRadians].
  /// Accurately snaps strokes to the ruler's top edge (numbers and tick marks).
  static Offset projectOntoRuler(Offset point, Offset origin, double angleRadians) {
    final cosA = math.cos(angleRadians);
    final sinA = math.sin(angleRadians);

    // The ruler top edge is 40px above center in local space.
    // In screen coordinates (y-down): dx = +40 * sin(angle), dy = -40 * cos(angle).
    final topEdgeOrigin = Offset(
      origin.dx + 40.0 * sinA,
      origin.dy - 40.0 * cosA,
    );

    // Vector from topEdgeOrigin to point
    final v = point - topEdgeOrigin;
    // Dot product with unit direction vector (cosA, sinA)
    final distanceAlongRuler = v.dx * cosA + v.dy * sinA;

    return Offset(
      topEdgeOrigin.dx + distanceAlongRuler * cosA,
      topEdgeOrigin.dy + distanceAlongRuler * sinA,
    );
  }
}
