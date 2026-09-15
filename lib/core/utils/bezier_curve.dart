import 'dart:ui';
import '../../models/point_model.dart';

class BezierCurveUtils {
  /// Generate smooth Path from sampled Point2D points
  static Path generateSmoothPath(List<Point2D> points) {
    final path = Path();
    if (points.isEmpty) return path;

    if (points.length == 1) {
      final p = points.first.toOffset();
      path.addOval(Rect.fromCircle(center: p, radius: 0.5));
      return path;
    }

    if (points.length == 2) {
      path.moveTo(points[0].x, points[0].y);
      path.lineTo(points[1].x, points[1].y);
      return path;
    }

    path.moveTo(points[0].x, points[0].y);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i].toOffset();
      final p1 = points[i + 1].toOffset();
      final midPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);

      path.quadraticBezierTo(p0.dx, p0.dy, midPoint.dx, midPoint.dy);
    }

    // Connect last segment
    final last = points.last.toOffset();
    final secondLast = points[points.length - 2].toOffset();
    path.quadraticBezierTo(secondLast.dx, secondLast.dy, last.dx, last.dy);

    return path;
  }
}
