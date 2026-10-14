import 'dart:math' as math;
import 'dart:ui';
import '../core/utils/geometry_utils.dart';
import '../models/point_model.dart';
import '../models/stroke_model.dart';

enum RecognizedShapeType {
  line,
  rectangle,
  circle,
  triangle,
  none,
}

class ShapeRecognizer {
  /// Attempt to recognize if a stroke represents a geometric shape.
  /// Requires deliberate dwell/hold at the end of the stroke (minimum 350ms)
  /// so natural handwriting is never accidentally converted into lines or shapes.
  static StrokeModel? tryRecognizeShape(
    StrokeModel stroke, {
    int endDwellMs = 0,
    bool forceRecognition = false,
  }) {
    final points = stroke.points;
    if (points.length < 5) return null;

    // Check dwell time: either passed explicitly (e.g. time between last move and pointerUp),
    // or calculated from end points clustering within 16px of the end point.
    bool hasDwell = forceRecognition || endDwellMs >= 350;
    if (!hasDwell && points.length >= 2) {
      final end = points.last.toOffset();
      int dwellStartTimestamp = points.last.timestamp;
      for (int i = points.length - 2; i >= 0; i--) {
        if ((points[i].toOffset() - end).distance <= 16.0) {
          dwellStartTimestamp = points[i].timestamp;
        } else {
          break;
        }
      }
      if ((points.last.timestamp - dwellStartTimestamp) >= 350) {
        hasDwell = true;
      }
    }

    if (!hasDwell) return null;

    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final totalDistance = (end - start).distance;

    // Calculate path length
    double pathLength = 0;
    for (int i = 0; i < points.length - 1; i++) {
      pathLength += (points[i + 1].toOffset() - points[i].toOffset()).distance;
    }

    if (pathLength < 30) return null;

    // 1. Check for straight line:
    // If direct distance between start and end is > 93% of the total path length, it's a line.
    // Snap nearly horizontal/vertical/45-degree lines (within 4 degrees) to exact angles.
    if (totalDistance / pathLength > 0.93) {
      Offset snappedEnd = end;
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final angle = math.atan2(dy, dx);
      const step45 = math.pi / 4;
      final nearestMultiple = (angle / step45).round() * step45;
      if ((angle - nearestMultiple).abs() <= (4.0 * math.pi / 180.0)) {
        snappedEnd = Offset(
          start.dx + totalDistance * math.cos(nearestMultiple),
          start.dy + totalDistance * math.sin(nearestMultiple),
        );
      }
      final snappedPoints = [
        Point2D(x: start.dx, y: start.dy, pressure: 1.0, timestamp: points.first.timestamp),
        Point2D(x: snappedEnd.dx, y: snappedEnd.dy, pressure: 1.0, timestamp: points.last.timestamp),
      ];
      return stroke.copyWith(points: snappedPoints);
    }

    // 2. Check for closed shapes (circle/ellipse, triangle, rectangle/square):
    // Start and end points must be relatively close together
    final isClosed = (end - start).distance < 0.28 * stroke.boundingBox.longestSide;
    if (isClosed && points.length >= 8) {
      final bounds = stroke.boundingBox;
      if (bounds.width < 20 || bounds.height < 20) return null;

      final center = bounds.center;
      final rx = bounds.width / 2.0;
      final ry = bounds.height / 2.0;

      // Measure normalized elliptical radial error:
      // For a true circle/ellipse, sqrt(((x-cx)/rx)^2 + ((y-cy)/ry)^2) ~ 1.0 everywhere.
      double radialErrorSum = 0.0;
      int cornerZoneCount = 0;
      double rectEdgeErrorSum = 0.0;

      for (final p in points) {
        final nx = (p.x - center.dx) / rx;
        final ny = (p.y - center.dy) / ry;
        final rho = math.sqrt(nx * nx + ny * ny);
        radialErrorSum += (rho - 1.0).abs();
        if (nx.abs() > 0.80 && ny.abs() > 0.80) {
          cornerZoneCount++;
        }

        final distLeft = (p.x - bounds.left).abs();
        final distRight = (p.x - bounds.right).abs();
        final distTop = (p.y - bounds.top).abs();
        final distBottom = (p.y - bounds.bottom).abs();
        final minEdgeDist = math.min(math.min(distLeft, distRight), math.min(distTop, distBottom));
        rectEdgeErrorSum += minEdgeDist / bounds.longestSide;
      }

      final avgRadialError = radialErrorSum / points.length;
      final avgRectEdgeError = rectEdgeErrorSum / points.length;
      final cornerRatio = cornerZoneCount / points.length;

      // Find 3 candidate triangle vertices:
      // v0 = point furthest from center, v1 = point furthest from v0, v2 = point with max distance to line v0-v1
      Offset v0 = start;
      double maxDistCenter = -1;
      for (final p in points) {
        final d = (p.toOffset() - center).distance;
        if (d > maxDistCenter) {
          maxDistCenter = d;
          v0 = p.toOffset();
        }
      }
      Offset v1 = v0;
      double maxDistV0 = -1;
      for (final p in points) {
        final d = (p.toOffset() - v0).distance;
        if (d > maxDistV0) {
          maxDistV0 = d;
          v1 = p.toOffset();
        }
      }
      Offset v2 = v0;
      double maxDistSeg = -1;
      for (final p in points) {
        final d = GeometryUtils.distanceToSegment(p.toOffset(), v0, v1);
        if (d > maxDistSeg) {
          maxDistSeg = d;
          v2 = p.toOffset();
        }
      }

      double triEdgeErrorSum = 0.0;
      for (final p in points) {
        final pt = p.toOffset();
        final d0 = GeometryUtils.distanceToSegment(pt, v0, v1);
        final d1 = GeometryUtils.distanceToSegment(pt, v1, v2);
        final d2 = GeometryUtils.distanceToSegment(pt, v2, v0);
        triEdgeErrorSum += math.min(d0, math.min(d1, d2)) / bounds.longestSide;
      }
      final avgTriEdgeError = triEdgeErrorSum / points.length;

      // A. Circle / Ellipse check: low radial deviation and few points in extreme bounding-box corners
      if (avgRadialError < 0.13 && cornerRatio < 0.15 && avgRadialError < avgRectEdgeError * 1.35) {
        final aspect = bounds.width / bounds.height;
        final isNearCircle = aspect >= 0.80 && aspect <= 1.25;
        final radiusX = isNearCircle ? (bounds.width + bounds.height) / 4.0 : rx;
        final radiusY = isNearCircle ? (bounds.width + bounds.height) / 4.0 : ry;

        final circlePoints = <Point2D>[];
        const segments = 28;
        for (int i = 0; i <= segments; i++) {
          final theta = (i * 2 * math.pi) / segments;
          circlePoints.add(Point2D(
            x: center.dx + radiusX * math.cos(theta),
            y: center.dy + radiusY * math.sin(theta),
            pressure: 1.0,
            timestamp: points.first.timestamp + i * 10,
          ));
        }
        return stroke.copyWith(points: circlePoints);
      }

      // B. Triangle check: points hug 3 segments much closer than a 4-sided box
      if (maxDistSeg > bounds.shortestSide * 0.45 &&
          avgTriEdgeError < 0.055 &&
          avgTriEdgeError < avgRectEdgeError * 0.72) {
        final triPoints = [
          Point2D(x: v0.dx, y: v0.dy, timestamp: points.first.timestamp),
          Point2D(x: v1.dx, y: v1.dy, timestamp: points.first.timestamp + 10),
          Point2D(x: v2.dx, y: v2.dy, timestamp: points.first.timestamp + 20),
          Point2D(x: v0.dx, y: v0.dy, timestamp: points.first.timestamp + 30),
        ];
        return stroke.copyWith(points: triPoints);
      }

      // C. Rectangle / Square check
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
