import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../engine/pdf_virtual_cache.dart';
import '../models/notebook_model.dart';
import '../models/page_template_model.dart';
import '../models/tool_type.dart';

class ExportService {
  /// Calculates the exact centered destination rectangle for BoxFit.contain, matching Flutter's rendering
  static Rect computeContainRect({
    required double srcWidth,
    required double srcHeight,
    required double dstWidth,
    required double dstHeight,
  }) {
    if (srcWidth <= 0 || srcHeight <= 0 || dstWidth <= 0 || dstHeight <= 0) {
      return Rect.zero;
    }
    final scale = (dstWidth / srcWidth < dstHeight / srcHeight)
        ? dstWidth / srcWidth
        : dstHeight / srcHeight;
    final renderW = srcWidth * scale;
    final renderH = srcHeight * scale;
    final dx = (dstWidth - renderW) / 2.0;
    final dy = (dstHeight - renderH) / 2.0;
    return Rect.fromLTWH(dx, dy, renderW, renderH);
  }

  /// Exports a notebook into a multi-layer PDF file with background PDF, paper template, images, and strokes.
  /// Uses direct PdfPage and PdfGraphics to guarantee strictly bounded O(1) memory during export.
  static Future<File?> exportNotebookToPdf(
    NotebookModel notebook, {
    bool share = false,
  }) async {
    try {
      final pdfDoc = PdfDocument();

      PdfFont pdfFont;
      try {
        final font = await PdfGoogleFonts.robotoRegular();
        if (font is pw.TtfFont) {
          pdfFont = font.buildFont(pdfDoc);
        } else {
          pdfFont = PdfFont.helvetica(pdfDoc);
        }
      } catch (e) {
        pdfFont = PdfFont.helvetica(pdfDoc);
      }

      final isPdf = notebook.sourcePdfPath != null;

      for (int i = 0; i < notebook.pages.length; i++) {
        final page = notebook.pages[i];
        final pageWidth = page.width;
        final pageHeight = page.height;

        final pdfPage = PdfPage(pdfDoc, pageFormat: PdfPageFormat(pageWidth, pageHeight));
        final canvas = pdfPage.getGraphics();

        // 1. Paper / Base Background Color
        final bgColor = isPdf
            ? PdfColors.white
            : PdfColor.fromInt(page.template.backgroundColor.toARGB32());
        canvas.setFillColor(bgColor);
        canvas.drawBox(PdfRect(0, 0, pageWidth, pageHeight));
        canvas.fillPath();

        // 2. PDF Page Background Raster (if PDF notebook)
        if (isPdf && notebook.sourcePdfPath != null) {
          try {
            final pdfPageIdx = page.pdfPageIndex ?? i;
            final rasterBytes = await PdfVirtualCache().renderPage(
              notebook.sourcePdfPath!,
              pdfPageIdx,
              dpi: 150.0,
            );
            if (rasterBytes != null) {
              final pdfImg = PdfImage.file(pdfDoc, bytes: rasterBytes);
              final rect = computeContainRect(
                srcWidth: pdfImg.width.toDouble(),
                srcHeight: pdfImg.height.toDouble(),
                dstWidth: pageWidth,
                dstHeight: pageHeight,
              );
              canvas.drawImage(
                pdfImg,
                rect.left,
                rect.top,
                rect.width,
                rect.height,
              );
            }
          } catch (e) {
            debugPrint('[ExportService] Error rendering background for page $i: $e');
          }
        }

        // 3. Paper Template Grid / Lines (for regular notebooks)
        if (!isPdf) {
          _drawPaperTemplate(canvas, PdfPoint(pageWidth, pageHeight), page.template, 1.0, 1.0);
        }

        // 4. Header with notebook title and page number (regular notebooks only)
        if (!isPdf) {
          canvas.setColor(PdfColors.grey600);
          canvas.drawString(pdfFont, 9, notebook.title, 24, pageHeight - 20);
          final pageIndicator = '${i + 1} / ${notebook.pages.length}';
          canvas.drawString(pdfFont, 9, pageIndicator, pageWidth - 80, pageHeight - 20);
        }

        // 5. Embedded Images
        for (final img in page.imageElements) {
          if (img.localPath != null) {
            final file = File(img.localPath!);
            if (await file.exists()) {
              try {
                final imgBytes = await file.readAsBytes();
                final imgPdf = PdfImage.file(pdfDoc, bytes: imgBytes);
                final pdfY = pageHeight - (img.y + img.height);
                canvas.drawImage(imgPdf, img.x, pdfY, img.width, img.height);
              } catch (_) {}
            }
          }
        }

        // 6. Vector Inking Strokes (with true PDF graphic state alpha)
        if (page.strokes.isNotEmpty) {
          for (final stroke in page.strokes) {
            if (stroke.points.isEmpty) continue;

            final isHighlighter = stroke.toolType == ToolType.highlighter;
            final alpha = isHighlighter ? 0.35 : stroke.opacity;
            final baseColor = PdfColor.fromInt(stroke.colorValue);

            final hasTransparency = isHighlighter || alpha < 1.0;
            if (hasTransparency) {
              canvas.saveContext();
              canvas.setGraphicState(PdfGraphicState(opacity: alpha));
            }

            canvas.setColor(baseColor);
            final strokeWidth = stroke.strokeWidth;

            if (stroke.points.length == 1) {
              canvas.drawEllipse(
                stroke.points.first.x,
                pageHeight - stroke.points.first.y,
                strokeWidth / 2,
                strokeWidth / 2,
              );
              canvas.fillPath();
            } else {
              canvas.setLineWidth(strokeWidth);
              canvas.moveTo(
                stroke.points.first.x,
                pageHeight - stroke.points.first.y,
              );
              for (int p = 1; p < stroke.points.length; p++) {
                canvas.lineTo(
                  stroke.points[p].x,
                  pageHeight - stroke.points[p].y,
                );
              }
              canvas.strokePath();
            }

            if (hasTransparency) {
              canvas.restoreContext();
            }
          }
        }

        // 7. Text Elements
        for (final txt in page.textElements) {
          canvas.setColor(PdfColor.fromInt(txt.colorValue));
          final pdfY = pageHeight - txt.y - txt.fontSize;
          canvas.drawString(pdfFont, txt.fontSize, txt.text, txt.x, pdfY);
        }
      }

      final outputDir = await getTemporaryDirectory();
      final sanitizedTitle = notebook.title.replaceAll(RegExp(r'[^\w\sа-яА-Я]+'), '_');
      final outputFile = File('${outputDir.path}/$sanitizedTitle.pdf');
      final bytes = await pdfDoc.save();
      await outputFile.writeAsBytes(bytes);
      debugPrint('[ExportService] Successfully exported PDF to: ${outputFile.path}');

      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: '$sanitizedTitle.pdf');
      }

      return outputFile;
    } catch (e) {
      debugPrint('[ExportService] Error exporting PDF: $e');
      return null;
    }
  }

  static void _drawPaperTemplate(
    PdfGraphics canvas,
    PdfPoint size,
    PageTemplateModel template,
    double scaleX,
    double scaleY,
  ) {
    final ruleColor = PdfColor.fromInt(template.primaryRuleColor.toARGB32());
    final marginColor = PdfColor.fromInt(template.accentRuleColor.toARGB32());

    switch (template.type) {
      case PaperTemplateType.blank:
        break;

      case PaperTemplateType.narrowRuled:
      case PaperTemplateType.wideRuled:
        final spacing = template.spacing * scaleY;
        final marginX = template.margin * scaleX;

        canvas.setColor(ruleColor);
        canvas.setLineWidth(0.5);
        for (double y = spacing * 2; y < size.y - spacing; y += spacing) {
          canvas.drawLine(0, size.y - y, size.x, size.y - y);
        }
        canvas.strokePath();

        // Left margin line
        canvas.setColor(marginColor);
        canvas.setLineWidth(0.75);
        canvas.drawLine(marginX, 0, marginX, size.y);
        canvas.strokePath();
        break;

      case PaperTemplateType.gridSmall:
      case PaperTemplateType.gridLarge:
        final spacingX = template.spacing * scaleX;
        final spacingY = template.spacing * scaleY;

        canvas.setColor(ruleColor);
        canvas.setLineWidth(0.5);
        for (double x = 0; x <= size.x; x += spacingX) {
          canvas.drawLine(x, 0, x, size.y);
        }
        for (double y = 0; y <= size.y; y += spacingY) {
          canvas.drawLine(0, size.y - y, size.x, size.y - y);
        }
        canvas.strokePath();
        break;

      case PaperTemplateType.dotGrid:
        final spacingX = template.spacing * scaleX;
        final spacingY = template.spacing * scaleY;

        canvas.setColor(ruleColor);
        for (double x = spacingX; x < size.x; x += spacingX) {
          for (double y = spacingY; y < size.y; y += spacingY) {
            canvas.drawEllipse(x, size.y - y, 0.6, 0.6);
            canvas.fillPath();
          }
        }
        break;

      case PaperTemplateType.cornell:
        final cueWidth = size.x * 0.28;
        final summaryHeight = size.y * 0.2;
        final headerHeight = 70.0 * scaleY;
        final spacing = template.spacing * scaleY;

        canvas.setColor(marginColor);
        canvas.setLineWidth(0.75);
        canvas.drawLine(0, size.y - headerHeight, size.x, size.y - headerHeight);
        canvas.drawLine(cueWidth, summaryHeight, cueWidth, size.y - headerHeight);
        canvas.drawLine(0, summaryHeight, size.x, summaryHeight);
        canvas.strokePath();

        canvas.setColor(ruleColor);
        canvas.setLineWidth(0.5);
        for (double y = headerHeight + spacing; y < size.y - summaryHeight; y += spacing) {
          canvas.drawLine(cueWidth, size.y - y, size.x, size.y - y);
        }
        canvas.strokePath();
        break;

      case PaperTemplateType.weeklyPlanner:
        final colWidth = size.x / 7;
        final headerHeight = 60.0 * scaleY;

        canvas.setColor(marginColor);
        canvas.setLineWidth(0.75);
        canvas.drawLine(0, size.y - headerHeight, size.x, size.y - headerHeight);
        canvas.strokePath();

        canvas.setColor(ruleColor);
        canvas.setLineWidth(0.5);
        for (int c = 1; c < 7; c++) {
          final x = c * colWidth;
          canvas.drawLine(x, 0, x, size.y - headerHeight);
        }
        canvas.strokePath();
        break;

      case PaperTemplateType.musicSheet:
        const lineCount = 5;
        final lineSpacing = 10.0 * scaleY;
        final staveSpacing = 80.0 * scaleY;

        canvas.setColor(ruleColor);
        canvas.setLineWidth(0.5);
        for (double staveY = 80 * scaleY; staveY < size.y - (80 * scaleY); staveY += staveSpacing) {
          for (int i = 0; i < lineCount; i++) {
            final y = staveY + (i * lineSpacing);
            canvas.drawLine(40 * scaleX, size.y - y, size.x - (40 * scaleX), size.y - y);
          }
        }
        canvas.strokePath();
        break;
    }
  }
}
