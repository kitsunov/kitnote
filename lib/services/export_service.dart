import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/notebook_model.dart';

class ExportService {
  /// Exports a notebook into a high-quality PDF file with handwritten strokes and text
  static Future<File?> exportNotebookToPdf(NotebookModel notebook) async {
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

      for (int i = 0; i < notebook.pages.length; i++) {
        final page = notebook.pages[i];

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              final pageWidth = PdfPageFormat.a4.width;
              final pageHeight = PdfPageFormat.a4.height;
              final scaleX = pageWidth / page.width;
              final scaleY = pageHeight / page.height;

              return pw.Stack(
                children: [
                  // 1. Background paper color
                  pw.Container(
                    width: pageWidth,
                    height: pageHeight,
                    color: PdfColor.fromInt(page.template.backgroundColor.toARGB32()),
                  ),

                  // 2. Header with notebook title and page number
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

                  // 3. Handwritten Vector Strokes
                  if (page.strokes.isNotEmpty)
                    pw.Positioned.fill(
                      child: pw.CustomPaint(
                        size: PdfPoint(pageWidth, pageHeight),
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          for (final stroke in page.strokes) {
                            if (stroke.points.isEmpty) continue;

                            canvas.setColor(PdfColor.fromInt(stroke.colorValue));

                            if (stroke.points.length == 1) {
                              canvas.drawEllipse(
                                stroke.points.first.x * scaleX,
                                size.y - (stroke.points.first.y * scaleY),
                                (stroke.strokeWidth * scaleX) / 2,
                                (stroke.strokeWidth * scaleY) / 2,
                              );
                              canvas.fillPath();
                              continue;
                            }

                            canvas.setLineWidth(stroke.strokeWidth * scaleX);
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
                        },
                      ),
                    ),

                  // 4. Text Elements
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
      return outputFile;
    } catch (e) {
      debugPrint('[ExportService] Error exporting PDF: $e');
      return null;
    }
  }
}
