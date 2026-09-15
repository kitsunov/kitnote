import 'dart:io';
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
  /// Exports a notebook into a multi-layer PDF file with background PDF, paper template, images, and strokes
  static Future<File?> exportNotebookToPdf(
    NotebookModel notebook, {
    bool share = false,
  }) async {
    try {
      pw.Font? ttfFont;
      try {
        ttfFont = await PdfGoogleFonts.robotoRegular();
      } catch (e) {
        debugPrint('[ExportService] Note: using default font: $e');
      }

      final doc = pw.Document(
        theme: ttfFont != null ? pw.ThemeData.withFont(base: ttfFont) : null,
      );

      final isPdf = notebook.sourcePdfPath != null;

      for (int i = 0; i < notebook.pages.length; i++) {
        final page = notebook.pages[i];

        // 1. Render background raster for this page just-in-time
        Uint8List? pdfBgBytes;
        if (isPdf && notebook.sourcePdfPath != null) {
          try {
            final pdfPageIdx = page.pdfPageIndex ?? i;
            pdfBgBytes = await PdfVirtualCache().renderPage(
              notebook.sourcePdfPath!,
              pdfPageIdx,
              dpi: 150.0,
            );
          } catch (e) {
            debugPrint('[ExportService] Error rendering background for page $i: $e');
          }
        }

        // 2. Load embedded images for this page
        final Map<String, Uint8List> pageImageBytes = {};
        for (final img in page.imageElements) {
          if (img.localPath != null) {
            final file = File(img.localPath!);
            if (await file.exists()) {
              try {
                pageImageBytes[img.localPath!] = await file.readAsBytes();
              } catch (_) {}
            }
          }
        }

        final pageWidth = page.width;
        final pageHeight = page.height;
        const scaleX = 1.0;
        const scaleY = 1.0;

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageWidth, pageHeight),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // 1. Paper / Base Background Color
                  pw.Container(
                    width: pageWidth,
                    height: pageHeight,
                    color: isPdf
                        ? PdfColors.white
                        : PdfColor.fromInt(page.template.backgroundColor.toARGB32()),
                  ),

                  // 2. PDF Page Background Raster (if PDF notebook)
                  if (pdfBgBytes != null)
                    pw.Positioned.fill(
                      child: pw.Image(
                        pw.MemoryImage(pdfBgBytes),
                        fit: pw.BoxFit.fill,
                      ),
                    ),

                  // 3. Paper Template Grid / Lines (for regular notebooks)
                  if (!isPdf)
                    pw.Positioned.fill(
                      child: pw.CustomPaint(
                        size: PdfPoint(pageWidth, pageHeight),
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          _drawPaperTemplate(canvas, size, page.template, scaleX, scaleY);
                        },
                      ),
                    ),

                  // 4. Header with notebook title and page number (regular notebooks only)
                  if (!isPdf)
                    pw.Positioned(
                      top: 16,
                      left: 24,
                      right: 24,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            notebook.title,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              font: ttfFont,
                            ),
                          ),
                          pw.Text(
                            '${i + 1} / ${notebook.pages.length}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                              font: ttfFont,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 5. Embedded Images
                  ...page.imageElements.map((img) {
                    final bytes = img.localPath != null ? pageImageBytes[img.localPath!] : null;
                    if (bytes == null) return pw.Container();

                    return pw.Positioned(
                      left: img.x * scaleX,
                      top: img.y * scaleY,
                      child: pw.Container(
                        width: img.width * scaleX,
                        height: img.height * scaleY,
                        child: pw.Image(
                          pw.MemoryImage(bytes),
                          fit: pw.BoxFit.cover,
                        ),
                      ),
                    );
                  }),

                  // 6. Vector Inking Strokes (with true PDF graphic state alpha)
                  if (page.strokes.isNotEmpty)
                    pw.Positioned.fill(
                      child: pw.CustomPaint(
                        size: PdfPoint(pageWidth, pageHeight),
                        painter: (PdfGraphics canvas, PdfPoint size) {
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

                            final strokeWidth = stroke.strokeWidth * scaleX;

                            if (stroke.points.length == 1) {
                              canvas.drawEllipse(
                                stroke.points.first.x * scaleX,
                                size.y - (stroke.points.first.y * scaleY),
                                strokeWidth / 2,
                                strokeWidth / 2,
                              );
                              canvas.fillPath();
                            } else {
                              canvas.setLineWidth(strokeWidth);
                              canvas.moveTo(
                                stroke.points.first.x * scaleX,
                                size.y - (stroke.points.first.y * scaleY),
                              );
                              for (int p = 1; p < stroke.points.length; p++) {
                                canvas.lineTo(
                                  stroke.points[p].x * scaleX,
                                  size.y - (stroke.points[p].y * scaleY),
                                );
                              }
                              canvas.strokePath();
                            }

                            if (hasTransparency) {
                              canvas.restoreContext();
                            }
                          }
                        },
                      ),
                    ),

                  // 7. Text Elements
                  ...page.textElements.map((txt) {
                    return pw.Positioned(
                      left: txt.x * scaleX,
                      top: txt.y * scaleY,
                      child: pw.Container(
                        width: txt.width * scaleX,
                        child: pw.Text(
                          txt.text,
                          style: pw.TextStyle(
                            fontSize: txt.fontSize * scaleX,
                            color: PdfColor.fromInt(txt.colorValue),
                            font: ttfFont,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      }

      final outputDir = await getTemporaryDirectory();
      final sanitizedTitle = notebook.title.replaceAll(RegExp(r'[^\w\sа-яА-Я]+'), '_');
      final outputFile = File('${outputDir.path}/$sanitizedTitle.pdf');
      final bytes = await doc.save();
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
