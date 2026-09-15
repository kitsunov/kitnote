import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/engine/pdf_virtual_cache.dart';

void main() {
  group('PdfVirtualCache Tests', () {
    test('getPdfPageCountFromBytes correctly parses single and multi-page counts', () {
      // Mock standard PDF trailer containing /Count 42
      final mockPdfBytes = utf8.encode(
        '%PDF-1.4\n1 0 obj\n<< /Type /Pages /Count 42 /Kids [2 0 R] >>\nendobj\n%%EOF',
      );

      final count = PdfVirtualCache.getPdfPageCountFromBytes(Uint8List.fromList(mockPdfBytes));
      expect(count, equals(42));
    });

    test('getPdfPageCountFromBytes finds max /Count in hierarchical page tree', () {
      final mockMultiTreePdf = utf8.encode(
        '%PDF-1.7\n'
        '2 0 obj << /Type /Pages /Count 5 >> endobj\n'
        '3 0 obj << /Type /Pages /Count 500 >> endobj\n'
        '4 0 obj << /Type /Pages /Count 25 >> endobj\n'
        '%%EOF',
      );

      final count = PdfVirtualCache.getPdfPageCountFromBytes(Uint8List.fromList(mockMultiTreePdf));
      expect(count, equals(500));
    });

    test('getPdfPageCountFromBytes ignores /Outlines count and picks /Pages count', () {
      final mockPdfWithOutlines = utf8.encode(
        '%PDF-1.7\n'
        '1 0 obj << /Type /Outlines /Count 120 /First 5 0 R >> endobj\n'
        '2 0 obj << /Type /Pages /Count 12 /Kids [3 0 R] >> endobj\n'
        '%%EOF',
      );

      final count = PdfVirtualCache.getPdfPageCountFromBytes(Uint8List.fromList(mockPdfWithOutlines));
      expect(count, equals(12));
    });

    test('getPdfPageCountFromBytes falls back to 1 for empty or non-pdf bytes', () {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final count = PdfVirtualCache.getPdfPageCountFromBytes(invalidBytes);
      expect(count, equals(1));
    });
  });
}
