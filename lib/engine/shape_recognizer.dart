import 'dart:math' as math;
import '../models/point_model.dart';
import '../models/stroke_model.dart';

enum RecognizedShapeType {
  line,
  rectangle,
  circle,
  none,
}

class ShapeRecognizer {
  /// Attempt to recognize if a stroke represents a geometric shape
  static StrokeModel? tryRecognizeShape(StrokeModel stroke) {
    final points = stroke.points;
    if (points.length < 5) return null;

    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final totalDistance = (end - start).distance;

    // Calculate path length
    double pathLength = 0;
    for (int i = 0; i < points.length - 1; i++) {
      pathLength += (points[i + 1].toOffset() - points[i].toOffset()).distance;
    }

    if (pathLength == 0) return null;

    // 1. Check for straight line:
    // If direct distance between start and end is > 92% of the total path length, it's a line
    if (totalDistance / pathLength > 0.92) {
      final snappedPoints = [
        Point2D(x: start.dx, y: start.dy, pressure: 1.0, timestamp: points.first.timestamp),
        Point2D(x: end.dx, y: end.dy, pressure: 1.0, timestamp: points.last.timestamp),
      ];
      return stroke.copyWith(points: snappedPoints);
    }

    // 2. Check for closed shapes (circle / rectangle):
    // Start and end points must be relatively close together
    final isClosed = (end - start).distance < 0.25 * stroke.boundingBox.longestSide;
    if (isClosed && points.length > 8) {
      final bounds = stroke.boundingBox;
      final aspect = bounds.width / (bounds.height == 0 ? 1 : bounds.height);

      // Circle test: aspect ratio close to 1:1, points roughly equidistant from center
      if (aspect >= 0.75 && aspect <= 1.33) {
        final center = bounds.center;
        final radius = (bounds.width + bounds.height) / 4;

        // Generate smooth circle points (16 segments)
        final circlePoints = <Point2D>[];
        const segments = 24;
        for (int i = 0; i <= segments; i++) {
          final theta = (i * 2 * math.pi) / segments;
          circlePoints.add(Point2D(
            x: center.dx + radius * math.cos(theta),
            y: center.dy + radius * math.sin(theta),
            pressure: 1.0,
            timestamp: points.first.timestamp + i * 10,
          ));
        }
        return stroke.copyWith(points: circlePoints);
      }

      // Rectangle test: 4 corners
      final rectPoints = [
        Point2D(x: bounds.left, y: bounds.top, timestamp: points.first.timestamp),
        Point2D(x: bounds.right, y: bounds.top, timestamp: points.first.timestamp + 10),
        Point2D(x: bounds.right, y: bounds.bottom, timestamp: points.first.timestamp + 20),
        Point2D(x: bounds.left, y: bounds.bottom, timestamp: points.first.timestamp + 30),
        Point2D(x: bounds.left, y: bounds.top, timestamp: points.first.timestamp + 40),
      ];
      return stroke.copyWith(points: rectPoints);
    }

    return null;
  }
}
