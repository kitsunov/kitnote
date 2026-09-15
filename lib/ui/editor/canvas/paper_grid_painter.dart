import 'package:flutter/material.dart';
import '../../../models/page_template_model.dart';

class PaperGridPainter extends CustomPainter {
  final PageTemplateModel template;

  const PaperGridPainter({required this.template});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill paper background color
    final bgPaint = Paint()..color = template.backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final rulePaint = Paint()
      ..color = template.primaryRuleColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final marginPaint = Paint()
      ..color = template.accentRuleColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    switch (template.type) {
      case PaperTemplateType.blank:
        // No grid lines needed
        break;

      case PaperTemplateType.narrowRuled:
      case PaperTemplateType.wideRuled:
        final spacing = template.spacing;
        final marginX = template.margin;

        // Draw horizontal lines
        for (double y = spacing * 2; y < size.height - spacing; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
        }

        // Draw vertical left margin line
        canvas.drawLine(Offset(marginX, 0), Offset(marginX, size.height), marginPaint);
        break;

      case PaperTemplateType.gridSmall:
      case PaperTemplateType.gridLarge:
        final spacing = template.spacing;

        // Vertical lines
        for (double x = 0; x <= size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), rulePaint);
        }

        // Horizontal lines
        for (double y = 0; y <= size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
        }
        break;

      case PaperTemplateType.dotGrid:
        final spacing = template.spacing;
        final dotPaint = Paint()
          ..color = template.primaryRuleColor
          ..style = PaintingStyle.fill;

        for (double x = spacing; x < size.width; x += spacing) {
          for (double y = spacing; y < size.height; y += spacing) {
            canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
          }
        }
        break;

      case PaperTemplateType.cornell:
        final cueWidth = size.width * 0.28;
        final summaryHeight = size.height * 0.2;
        const headerHeight = 70.0;

        // Header horizontal line
        canvas.drawLine(const Offset(0, headerHeight), Offset(size.width, headerHeight), marginPaint);

        // Cue vertical column line
        canvas.drawLine(Offset(cueWidth, headerHeight), Offset(cueWidth, size.height - summaryHeight), marginPaint);

        // Summary horizontal footer line
        canvas.drawLine(Offset(0, size.height - summaryHeight), Offset(size.width, size.height - summaryHeight), marginPaint);

        // Notes area horizontal lines
        final spacing = template.spacing;
        for (double y = headerHeight + spacing; y < size.height - summaryHeight; y += spacing) {
          canvas.drawLine(Offset(cueWidth, y), Offset(size.width, y), rulePaint);
        }
        break;

      case PaperTemplateType.weeklyPlanner:
        final colWidth = size.width / 7;
        const headerHeight = 60.0;

        canvas.drawLine(const Offset(0, headerHeight), Offset(size.width, headerHeight), marginPaint);

        for (int i = 1; i < 7; i++) {
          final x = i * colWidth;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), rulePaint);
        }

        // Planner rows
        const rowSpacing = 40.0;
        for (double y = headerHeight + rowSpacing; y < size.height; y += rowSpacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), rulePaint);
        }
        break;

      case PaperTemplateType.musicSheet:
        const lineCount = 5;
        const lineSpacing = 10.0;
        const staveSpacing = 80.0;

        for (double staveY = 80; staveY < size.height - 80; staveY += staveSpacing) {
          for (int i = 0; i < lineCount; i++) {
            final y = staveY + (i * lineSpacing);
            canvas.drawLine(Offset(40, y), Offset(size.width - 40, y), rulePaint);
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant PaperGridPainter oldDelegate) {
    return oldDelegate.template.type != template.type ||
        oldDelegate.template.colorTheme != template.colorTheme ||
        oldDelegate.template.spacing != template.spacing;
  }
}
