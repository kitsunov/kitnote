import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/models/notebook_model.dart';
import 'package:kitnote/models/page_model.dart';
import 'package:kitnote/models/point_model.dart';
import 'package:kitnote/models/stroke_model.dart';
import 'package:kitnote/models/text_element_model.dart';
import 'package:kitnote/models/tool_type.dart';
import 'package:kitnote/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
  });

  group('ExportService Tests', () {
    test('computeContainRect computes exact BoxFit.contain centered rect', () {
      // Case 1: Taller source in square destination (centered horizontally)
      final rect1 = ExportService.computeContainRect(
        srcWidth: 1000,
        srcHeight: 2000,
        dstWidth: 1000,
        dstHeight: 1000,
      );
      expect(rect1.width, closeTo(500.0, 0.001));
      expect(rect1.height, closeTo(1000.0, 0.001));
      expect(rect1.left, closeTo(250.0, 0.001));
      expect(rect1.top, closeTo(0.0, 0.001));

      // Case 2: Wider source in square destination (centered vertically)
      final rect2 = ExportService.computeContainRect(
        srcWidth: 2000,
        srcHeight: 1000,
        dstWidth: 1000,
        dstHeight: 1000,
      );
      expect(rect2.width, closeTo(1000.0, 0.001));
      expect(rect2.height, closeTo(500.0, 0.001));
      expect(rect2.left, closeTo(0.0, 0.001));
      expect(rect2.top, closeTo(250.0, 0.001));

      // Case 3: Same aspect ratio
      final rect3 = ExportService.computeContainRect(
        srcWidth: 500,
        srcHeight: 1000,
        dstWidth: 1000,
        dstHeight: 2000,
      );
      expect(rect3.width, closeTo(1000.0, 0.001));
      expect(rect3.height, closeTo(2000.0, 0.001));
      expect(rect3.left, closeTo(0.0, 0.001));
      expect(rect3.top, closeTo(0.0, 0.001));
    });

    test('exportNotebookToPdf exports multi-page notebook with strokes and text', () async {
      final pages = <PageModel>[];
      for (int i = 0; i < 5; i++) {
        pages.add(PageModel(
          id: 'page_$i',
          pageIndex: i,
          width: 800,
          height: 1100,
          strokes: [
            StrokeModel(
              id: 'stroke_${i}_1',
              points: const [
                Point2D(x: 50, y: 50, timestamp: 100),
                Point2D(x: 100, y: 150, timestamp: 200),
                Point2D(x: 200, y: 250, timestamp: 300),
              ],
              colorValue: 0xFF000000,
              strokeWidth: 2.5,
              opacity: 1.0,
              toolType: ToolType.fountainPen,
            ),
            StrokeModel(
              id: 'stroke_${i}_hl',
              points: const [
                Point2D(x: 100, y: 300, timestamp: 400),
                Point2D(x: 300, y: 300, timestamp: 500),
              ],
              colorValue: 0xFFFFEB3B,
              strokeWidth: 12.0,
              opacity: 0.35,
              toolType: ToolType.highlighter,
            ),
          ],
          textElements: [
            TextElementModel(
              id: 'txt_${i}_1',
              text: 'Page ${i + 1} Annotation Text',
              x: 120,
              y: 280,
              fontSize: 16,
              colorValue: 0xFF1E293B,
            ),
          ],
        ));
      }

      final notebook = NotebookModel(
        id: 'export_stress_test_nb',
        title: 'Export Stress Test',
        pages: pages,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final exportedFile = await ExportService.exportNotebookToPdf(notebook);
      expect(exportedFile, isNotNull);
      expect(await exportedFile!.exists(), isTrue);

      final fileSize = await exportedFile.length();
      expect(fileSize, greaterThan(1000));

      // Clean up temporary file
      try {
        await exportedFile.delete();
      } catch (_) {}
    });
  });
}
