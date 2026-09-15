import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/notebook_model.dart';

class ExportService {
  /// Exports a notebook into a high-quality PDF file
  static Future<File?> exportNotebookToPdf(NotebookModel notebook) async {
    try {
      final doc = pw.Document();

      for (int i = 0; i < notebook.pages.length; i++) {
        final page = notebook.pages[i];

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // Background color
                  pw.Container(
                    color: PdfColor.fromInt(page.template.backgroundColor.toARGB32()),
                  ),

                  // Header with title and page number
                  pw.Positioned(
                    top: 20,
                    left: 30,
                    right: 30,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          notebook.title,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          'Стр. ${i + 1} / ${notebook.pages.length}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Text elements
                  ...page.textElements.map((txt) {
                    return pw.Positioned(
                      left: txt.x * 0.45,
                      top: txt.y * 0.45,
                      child: pw.Container(
                        width: txt.width * 0.45,
                        child: pw.Text(
                          txt.text,
                          style: pw.TextStyle(
                            fontSize: txt.fontSize * 0.45,
                            color: PdfColor.fromInt(txt.colorValue),
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
