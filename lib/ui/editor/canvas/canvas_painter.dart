import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/bezier_curve.dart';
import '../../../models/point_model.dart';
import '../../../models/stroke_model.dart';
import '../../../models/tool_type.dart';

class CanvasPainter extends CustomPainter {
  final List<StrokeModel> strokes;
  final List<Point2D> activeStrokePoints;
  final ToolType activeTool;
  final int activeColor;
  final double activeStrokeWidth;
  final List<Offset> lassoPoints;
  final bool isLassoActive;
  final Set<String> selectedStrokeIds;

  const CanvasPainter({
    required this.strokes,
    required this.activeStrokePoints,
    required this.activeTool,
    required this.activeColor,
    required this.activeStrokeWidth,
    required this.lassoPoints,
    required this.isLassoActive,
    required this.selectedStrokeIds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Highlighters first (so they blend naturally beneath ink)
    for (final stroke in strokes) {
      if (stroke.toolType == ToolType.highlighter) {
        _drawSingleStroke(canvas, stroke);
      }
    }

    // 2. Draw standard ink strokes
    for (final stroke in strokes) {
      if (stroke.toolType != ToolType.highlighter) {
        _drawSingleStroke(canvas, stroke);
      }
    }

    // 3. Highlight selected strokes (from Lasso)
    if (selectedStrokeIds.isNotEmpty) {
      final highlightPaint = Paint()
        ..color = const Color(0x663B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      for (final stroke in strokes) {
        if (selectedStrokeIds.contains(stroke.id)) {
          final bounds = stroke.boundingBox.inflate(4.0);
          canvas.drawRRect(
            RRect.fromRectAndRadius(bounds, const Radius.circular(6)),
            highlightPaint,
          );
        }
      }
    }

    // 4. Draw active in-progress stroke
    if (activeStrokePoints.isNotEmpty) {
      final isHighlighter = activeTool == ToolType.highlighter;
      final opacity = isHighlighter ? 0.35 : 1.0;
      final width = activeStrokeWidth;

      final tempStroke = StrokeModel(
        id: 'active_preview',
        points: activeStrokePoints,
        colorValue: activeColor,
        strokeWidth: width,
        opacity: opacity,
        toolType: activeTool,
      );
      drawSingleStroke(canvas, tempStroke);
    }

    // 5. Draw Lasso selection loop
    if (lassoPoints.isNotEmpty) {
      drawLassoLoop(canvas, lassoPoints, isLassoActive);
    }
  }

  static void drawLassoLoop(Canvas canvas, List<Offset> lassoPoints, bool isLassoActive) {
    if (lassoPoints.isEmpty) return;
    final lassoPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final lassoFill = Paint()
      ..color = const Color(0x1A2563EB)
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(lassoPoints.first.dx, lassoPoints.first.dy);
    for (int i = 1; i < lassoPoints.length; i++) {
      path.lineTo(lassoPoints[i].dx, lassoPoints[i].dy);
    }
    if (!isLassoActive) {
      path.close();
      canvas.drawPath(path, lassoFill);
    }
    canvas.drawPath(path, lassoPaint);
  }

  void _drawSingleStroke(Canvas canvas, StrokeModel stroke) => drawSingleStroke(canvas, stroke);

  static void drawSingleStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      final paint = Paint()
        ..color = stroke.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.toOffset(), stroke.strokeWidth / 2, paint);
      return;
    }

    final isHighlighter = stroke.toolType == ToolType.highlighter;

    if (stroke.toolType == ToolType.ballpointPen || isHighlighter) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = isHighlighter ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (isHighlighter) {
        paint.blendMode = BlendMode.multiply;
      }

      final path = BezierCurveUtils.generateSmoothPath(stroke.points);
      canvas.drawPath(path, paint);
    } else if (stroke.toolType == ToolType.fountainPen) {
      // Fountain Pen: pressure & speed modulated width (0.35x - 1.5x)
      final baseWidth = stroke.strokeWidth;
      final baseColor = stroke.color;
      final minWidth = math.max(0.2, baseWidth * 0.2);
      final maxWidth = math.max(minWidth, baseWidth * 2.2);
      final segPaint = Paint()
        ..color = baseColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];

        double press0 = p0.pressure > 0 && p0.pressure != 1.0 ? p0.pressure : 0.7;
        double press1 = p1.pressure > 0 && p1.pressure != 1.0 ? p1.pressure : 0.7;

        if (p0.pressure == 1.0 && p1.pressure == 1.0 && p1.timestamp > p0.timestamp) {
          final dt = (p1.timestamp - p0.timestamp).clamp(1, 100);
          final dist = (p1.toOffset() - p0.toOffset()).distance;
          final speed = dist / dt;
          final speedFactor = (1.25 - speed * 0.35).clamp(0.4, 1.4);
          press0 = speedFactor;
          press1 = speedFactor;
        }

        final w = (baseWidth * (0.35 + 0.85 * ((press0 + press1) / 2))).clamp(minWidth, maxWidth);
        segPaint.strokeWidth = w;

        canvas.drawLine(p0.toOffset(), p1.toOffset(), segPaint);
      }
    } else if (stroke.toolType == ToolType.brushPen) {
      // Brush Pen: Calligraphic angle modulation + start/end taper
      final baseWidth = stroke.strokeWidth;
      final baseColor = stroke.color;
      final total = stroke.points.length;
      final minWidth = math.max(0.2, baseWidth * 0.2);
      final maxWidth = math.max(minWidth, baseWidth * 2.5);
      final segPaint = Paint()
        ..color = baseColor
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];

        double taper = 1.0;
        if (i < 4) {
          taper = (i + 1) / 5.0;
        } else if (i > total - 6) {
          taper = (total - i) / 6.0;
        }

        final dx = p1.x - p0.x;
        final dy = p1.y - p0.y;
        final angle = math.atan2(dy, dx);
        final angleFactor = 0.45 + 0.75 * math.sin(angle + math.pi / 4).abs();

        final p0Press = p0.pressure > 0 ? p0.pressure : 0.8;
        final w = (baseWidth * angleFactor * taper * (0.5 + 0.6 * p0Press)).clamp(minWidth, maxWidth);
        segPaint.strokeWidth = w;

        canvas.drawLine(p0.toOffset(), p1.toOffset(), segPaint);
      }
    } else if (stroke.toolType == ToolType.laserPointer) {
      final path = BezierCurveUtils.generateSmoothPath(stroke.points);
      final glowPaint = Paint()
        ..color = const Color(0x99EF4444)
        ..strokeWidth = stroke.strokeWidth * 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      final corePaint = Paint()
        ..color = const Color(0xFFFF4D4D)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, corePaint);

      final lastPt = stroke.points.last.toOffset();
      canvas.drawCircle(
        lastPt,
        stroke.strokeWidth * 1.4,
        Paint()
          ..color = const Color(0xAAEF4444)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );
      canvas.drawCircle(
        lastPt,
        stroke.strokeWidth * 0.65,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    } else {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = BezierCurveUtils.generateSmoothPath(stroke.points);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return activeStrokePoints.isNotEmpty ||
        oldDelegate.activeStrokePoints.isNotEmpty ||
        isLassoActive ||
        oldDelegate.isLassoActive ||
        !identical(strokes, oldDelegate.strokes) ||
        strokes.length != oldDelegate.strokes.length ||
        lassoPoints.length != oldDelegate.lassoPoints.length ||
        selectedStrokeIds.length != oldDelegate.selectedStrokeIds.length ||
        !setEquals(selectedStrokeIds, oldDelegate.selectedStrokeIds);
  }
}

/// Dedicated painter for the in-progress active stroke, ephemeral laser strokes, and active lasso loop.
/// Wrapped in its own [RepaintBoundary] so drawing at 60–120 FPS never repaints committed strokes.
class ActiveStrokePainter extends CustomPainter {
  final List<Point2D> activeStrokePoints;
  final List<StrokeModel> laserStrokes;
  final ToolType activeTool;
  final int activeColor;
  final double activeStrokeWidth;
  final List<Offset> lassoPoints;
  final bool isLassoActive;

  const ActiveStrokePainter({
    required this.activeStrokePoints,
    this.laserStrokes = const [],
    required this.activeTool,
    required this.activeColor,
    required this.activeStrokeWidth,
    required this.lassoPoints,
    required this.isLassoActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final laser in laserStrokes) {
      CanvasPainter.drawSingleStroke(canvas, laser);
    }

    if (activeStrokePoints.isNotEmpty) {
      final isHighlighter = activeTool == ToolType.highlighter;
      final isLaser = activeTool == ToolType.laserPointer;
      final opacity = isHighlighter ? 0.35 : 1.0;

      final tempStroke = StrokeModel(
        id: 'active_preview',
        points: activeStrokePoints,
        colorValue: isLaser ? 0xFFEF4444 : activeColor,
        strokeWidth: isLaser ? 4.5 : activeStrokeWidth,
        opacity: opacity,
        toolType: activeTool,
      );
      CanvasPainter.drawSingleStroke(canvas, tempStroke);
    }

    if (lassoPoints.isNotEmpty) {
      CanvasPainter.drawLassoLoop(canvas, lassoPoints, isLassoActive);
    }
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return activeStrokePoints.isNotEmpty ||
        oldDelegate.activeStrokePoints.isNotEmpty ||
        laserStrokes.length != oldDelegate.laserStrokes.length ||
        isLassoActive ||
        oldDelegate.isLassoActive ||
        lassoPoints.length != oldDelegate.lassoPoints.length ||
        activeTool != oldDelegate.activeTool ||
        activeColor != oldDelegate.activeColor ||
        activeStrokeWidth != oldDelegate.activeStrokeWidth;
  }
}
