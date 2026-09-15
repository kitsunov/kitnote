import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/core/utils/geometry_utils.dart';
import 'package:kitnote/models/point_model.dart';
import 'package:kitnote/models/stroke_model.dart';
import 'package:kitnote/models/tool_type.dart';

void main() {
  group('GeometryUtils Tests', () {
    test('distanceToSegment correctly computes distance to line segment', () {
      const a = Offset(0, 0);
      const b = Offset(10, 0);

      // Point directly above middle
      expect(GeometryUtils.distanceToSegment(const Offset(5, 5), a, b), closeTo(5.0, 0.001));

      // Point beyond end
      expect(GeometryUtils.distanceToSegment(const Offset(15, 0), a, b), closeTo(5.0, 0.001));

      // Point directly on segment
      expect(GeometryUtils.distanceToSegment(const Offset(3, 0), a, b), closeTo(0.0, 0.001));
    });

    test('isPointInPolygon detects inside and outside points for Lasso', () {
      final triangle = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(5, 10),
      ];

      // Point inside triangle
      expect(GeometryUtils.isPointInPolygon(const Offset(5, 3), triangle), isTrue);

      // Point outside triangle
      expect(GeometryUtils.isPointInPolygon(const Offset(15, 5), triangle), isFalse);
      expect(GeometryUtils.isPointInPolygon(const Offset(-2, 2), triangle), isFalse);
    });

    test('projectOntoRuler projects points onto ruler axis', () {
      const origin = Offset(100, 100);
      const angle = 0.0; // Horizontal ruler

      const point = Offset(150, 120);
      final projected = GeometryUtils.projectOntoRuler(point, origin, angle);

      expect(projected.dx, closeTo(150.0, 0.001));
      expect(projected.dy, closeTo(100.0, 0.001));
    });

    test('isStrokeHitByPoint detects eraser collision', () {
      const stroke = StrokeModel(
        id: 'test_stroke',
        points: [
          Point2D(x: 10, y: 10, timestamp: 0),
          Point2D(x: 50, y: 50, timestamp: 10),
        ],
        colorValue: 0xFF000000,
        strokeWidth: 4.0,
        toolType: ToolType.ballpointPen,
      );

      // Eraser touching midpoint (30, 30) with radius 10
      expect(GeometryUtils.isStrokeHitByPoint(stroke, const Offset(30, 30), 10.0), isTrue);

      // Eraser far away (200, 200)
      expect(GeometryUtils.isStrokeHitByPoint(stroke, const Offset(200, 200), 10.0), isFalse);
    });

    test('isStrokeHitByPoint handles single-point dot strokes', () {
      const dotStroke = StrokeModel(
        id: 'dot_stroke',
        points: [
          Point2D(x: 100, y: 100, timestamp: 0),
        ],
        colorValue: 0xFF000000,
        strokeWidth: 4.0,
        toolType: ToolType.ballpointPen,
      );

      // Eraser touching dot
      expect(GeometryUtils.isStrokeHitByPoint(dotStroke, const Offset(102, 101), 10.0), isTrue);

      // Eraser outside dot
      expect(GeometryUtils.isStrokeHitByPoint(dotStroke, const Offset(125, 125), 10.0), isFalse);
    });
  });
}
