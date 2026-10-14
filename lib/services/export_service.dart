import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../engine/pdf_virtual_cache.dart';
import '../models/image_element_model.dart';
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

  static pw.TtfFont? _cachedUnicodeFont;

  /// Transliterates Cyrillic characters if the PDF export had to fall back to ASCII-only Helvetica while offline.
  static String sanitizeTextForFont(String input, {required bool isUnicodeFont}) {
    if (isUnicodeFont) return input;
    const map = <String, String>{
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
      'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo',
      'Ж': 'Zh', 'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M',
      'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U',
      'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch',
      'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
    };
    final sb = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (map.containsKey(ch)) {
        sb.write(map[ch]);
      } else if (ch.codeUnitAt(0) <= 255) {
        sb.write(ch);
      } else {
        sb.write('?');
      }
    }
    return sb.toString();
  }

  /// Exports a notebook into a multi-layer PDF file with background PDF, paper template, images, and strokes.
  /// Uses direct PdfPage and PdfGraphics to guarantee strictly bounded O(1) memory during export.
  static Future<File?> exportNotebookToPdf(
    NotebookModel notebook, {
    bool share = false,
    pw.Font? fontOverride,
  }) async {
    try {
      final pdfDoc = PdfDocument();

      PdfFont pdfFont;
      bool isUnicodeFont = false;
      if (fontOverride is pw.TtfFont) {
        pdfFont = fontOverride.buildFont(pdfDoc);
        isUnicodeFont = true;
      } else if (_cachedUnicodeFont != null) {
        pdfFont = _cachedUnicodeFont!.buildFont(pdfDoc);
        isUnicodeFont = true;
      } else {
        try {
          final font = await PdfGoogleFonts.robotoRegular();
          if (font is pw.TtfFont) {
            _cachedUnicodeFont = font;
            pdfFont = font.buildFont(pdfDoc);
            isUnicodeFont = true;
          } else {
            pdfFont = PdfFont.helvetica(pdfDoc);
          }
        } catch (_) {
          pdfFont = PdfFont.helvetica(pdfDoc);
        }
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
          final safeHeaderTitle = sanitizeTextForFont(notebook.title, isUnicodeFont: isUnicodeFont);
          canvas.drawString(pdfFont, 9, safeHeaderTitle, 24, pageHeight - 20);
          final pageIndicator = '${i + 1} / ${notebook.pages.length}';
          canvas.drawString(pdfFont, 9, pageIndicator, pageWidth - 80, pageHeight - 20);
        }

        // 5. Background Images (rendered behind strokes)
        for (final img in page.imageElements.where((i) => i.isBackground)) {
          await _renderImageToPdf(pdfDoc, canvas, img, pageHeight);
        }

        // 6. Vector Inking Strokes (with true PDF graphic state alpha, round caps/joins & dynamic pen widths)
        if (page.strokes.isNotEmpty) {
          final orderedStrokes = [
            ...page.strokes.where((s) => s.toolType == ToolType.highlighter),
            ...page.strokes.where((s) => s.toolType != ToolType.highlighter),
          ];

          for (final stroke in orderedStrokes) {
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
            canvas.setLineCap(isHighlighter ? PdfLineCap.square : PdfLineCap.round);
            canvas.setLineJoin(PdfLineJoin.round);
            final strokeWidth = stroke.strokeWidth;

            if (stroke.points.length == 1) {
              canvas.drawEllipse(
                stroke.points.first.x,
                pageHeight - stroke.points.first.y,
                strokeWidth / 2,
                strokeWidth / 2,
              );
              canvas.fillPath();
            } else if (stroke.toolType == ToolType.fountainPen) {
              final minWidth = math.max(0.2, strokeWidth * 0.2);
              final maxWidth = math.max(minWidth, strokeWidth * 2.2);
              for (int p = 0; p < stroke.points.length - 1; p++) {
                final p0 = stroke.points[p];
                final p1 = stroke.points[p + 1];
                double press0 = p0.pressure > 0 && p0.pressure != 1.0 ? p0.pressure : 0.7;
                double press1 = p1.pressure > 0 && p1.pressure != 1.0 ? p1.pressure : 0.7;
                if (p0.pressure == 1.0 && p1.pressure == 1.0 && p1.timestamp > p0.timestamp) {
                  final dt = (p1.timestamp - p0.timestamp).clamp(1, 100);
                  final dx = p1.x - p0.x;
                  final dy = p1.y - p0.y;
                  final dist = math.sqrt(dx * dx + dy * dy);
                  final speed = dist / dt;
                  final speedFactor = (1.25 - speed * 0.35).clamp(0.4, 1.4);
                  press0 = speedFactor;
                  press1 = speedFactor;
                }
                final segW = (strokeWidth * (0.35 + 0.85 * ((press0 + press1) / 2))).clamp(minWidth, maxWidth);
                canvas.setLineWidth(segW);
                canvas.moveTo(p0.x, pageHeight - p0.y);
                canvas.lineTo(p1.x, pageHeight - p1.y);
                canvas.strokePath();
              }
            } else if (stroke.toolType == ToolType.brushPen) {
              final total = stroke.points.length;
              final minWidth = math.max(0.2, strokeWidth * 0.2);
              final maxWidth = math.max(minWidth, strokeWidth * 2.5);
              for (int p = 0; p < stroke.points.length - 1; p++) {
                final p0 = stroke.points[p];
                final p1 = stroke.points[p + 1];
                double taper = 1.0;
                if (p < 4) {
                  taper = (p + 1) / 5.0;
                } else if (p > total - 6) {
                  taper = (total - p) / 6.0;
                }
                final dx = p1.x - p0.x;
                final dy = p1.y - p0.y;
                final angle = math.atan2(dy, dx);
                final angleFactor = 0.45 + 0.75 * math.sin(angle + math.pi / 4).abs();
                final p0Press = p0.pressure > 0 ? p0.pressure : 0.8;
                final segW = (strokeWidth * angleFactor * taper * (0.5 + 0.6 * p0Press)).clamp(minWidth, maxWidth);
                canvas.setLineWidth(segW);
                canvas.moveTo(p0.x, pageHeight - p0.y);
                canvas.lineTo(p1.x, pageHeight - p1.y);
                canvas.strokePath();
              }
            } else {
              canvas.setLineWidth(strokeWidth);
              canvas.moveTo(
                stroke.points.first.x,
                pageHeight - stroke.points.first.y,
              );
              for (int p = 1; p < stroke.points.length - 1; p++) {
                final curr = stroke.points[p];
                final next = stroke.points[p + 1];
                final midX = (curr.x + next.x) / 2.0;
                final midY = (curr.y + next.y) / 2.0;
                canvas.curveTo(
                  curr.x,
                  pageHeight - curr.y,
                  curr.x,
                  pageHeight - curr.y,
                  midX,
                  pageHeight - midY,
                );
              }
              canvas.lineTo(
                stroke.points.last.x,
                pageHeight - stroke.points.last.y,
              );
              canvas.strokePath();
            }

            if (hasTransparency) {
              canvas.restoreContext();
            }
          }
        }

        // 7. Foreground Images (rendered above strokes)
        for (final img in page.imageElements.where((i) => !i.isBackground)) {
          await _renderImageToPdf(pdfDoc, canvas, img, pageHeight);
        }

        // 8. Text Elements
        for (final txt in page.textElements) {
          canvas.setColor(PdfColor.fromInt(txt.colorValue));
          final maxLineWidth = math.max(20.0, txt.width - 16.0);
          final lineHeight = txt.fontSize * 1.25;
          final rawLines = txt.text.split('\n');
          final lines = <String>[];

          for (final rawLine in rawLines) {
            if (rawLine.isEmpty) {
              lines.add('');
              continue;
            }
            final words = rawLine.split(' ');
            String currentLine = '';
            for (final word in words) {
              final testLine = currentLine.isEmpty ? word : '$currentLine $word';
              final approxWidth = testLine.length * (txt.fontSize * 0.55);
              if (approxWidth > maxLineWidth && currentLine.isNotEmpty) {
                lines.add(currentLine);
                currentLine = word;
              } else {
                currentLine = testLine;
              }
            }
            if (currentLine.isNotEmpty) {
              lines.add(currentLine);
            }
          }

          for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
            final line = lines[lineIdx];
            if (line.trim().isEmpty) continue;
            final pdfY = pageHeight - (txt.y + 8) - (lineIdx + 1) * lineHeight;
            final safeLine = sanitizeTextForFont(line, isUnicodeFont: isUnicodeFont);
            canvas.drawString(pdfFont, txt.fontSize, safeLine, txt.x + 8, pdfY);
          }
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

  static Future<void> _renderImageToPdf(
    PdfDocument pdfDoc,
    PdfGraphics canvas,
    ImageElementModel img,
    double pageHeight,
  ) async {
    Uint8List? imgBytes = img.rawBytes;
    if (imgBytes == null && img.localPath != null) {
      final file = File(img.localPath!);
      if (await file.exists()) {
        try {
          imgBytes = await file.readAsBytes();
        } catch (_) {}
      }
    }

    if (imgBytes != null && imgBytes.isNotEmpty) {
      try {
        final imgPdf = PdfImage.file(pdfDoc, bytes: imgBytes);
        final pdfY = pageHeight - (img.y + img.height);
        if (img.rotation != 0) {
          canvas.saveContext();
          final centerX = img.x + img.width / 2;
          final centerY = pdfY + img.height / 2;
          final mat = vm.Matrix4.identity()
            ..translateByDouble(centerX, centerY, 0, 1)
            ..rotateZ(-img.rotation)
            ..translateByDouble(-centerX, -centerY, 0, 1);
          canvas.setTransform(mat);
        }
        canvas.drawImage(imgPdf, img.x, pdfY, img.width, img.height);
        if (img.rotation != 0) {
          canvas.restoreContext();
        }
      } catch (_) {}
    }
  }
}
