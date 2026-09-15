import 'dart:math' as math;
import 'dart:ui';
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

  /// Project a point onto a ruler line defined by [origin] and [angleRadians]
  static Offset projectOntoRuler(Offset point, Offset origin, double angleRadians) {
    final cosA = math.cos(angleRadians);
    final sinA = math.sin(angleRadians);

    // Vector from origin to point
    final v = point - origin;
    // Dot product with unit direction vector (cosA, sinA)
    final distanceAlongRuler = v.dx * cosA + v.dy * sinA;

    return Offset(
      origin.dx + distanceAlongRuler * cosA,
      origin.dy + distanceAlongRuler * sinA,
    );
  }
}
