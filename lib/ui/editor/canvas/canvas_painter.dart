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
      final width = isHighlighter ? activeStrokeWidth * 3.5 : activeStrokeWidth;

      final paint = Paint()
        ..color = Color(activeColor).withValues(alpha: opacity)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (isHighlighter) {
        paint.blendMode = BlendMode.multiply;
      }

      final path = BezierCurveUtils.generateSmoothPath(activeStrokePoints);
      canvas.drawPath(path, paint);
    }

    // 5. Draw Lasso selection loop
    if (lassoPoints.isNotEmpty) {
      final lassoPaint = Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

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
  }

  void _drawSingleStroke(Canvas canvas, StrokeModel stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.toolType == ToolType.highlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    final path = BezierCurveUtils.generateSmoothPath(stroke.points);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return true; // Fast dynamic repaint during live inking
  }
}
