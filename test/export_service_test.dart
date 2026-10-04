import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/models/image_element_model.dart';
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

    test('exportNotebookToPdf exports notebook with background and foreground images using rawBytes', () async {
      final validPng = Uint8List.fromList([
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
        0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
        120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78,
        68, 174, 66, 96, 130
      ]);

      final notebook = NotebookModel(
        id: 'nb_images_test',
        title: 'Image Layers Test',
        pages: [
          PageModel(
            id: 'page_img_1',
            pageIndex: 0,
            width: 800,
            height: 1100,
            imageElements: [
              ImageElementModel(
                id: 'bg_img',
                x: 50,
                y: 50,
                width: 200,
                height: 200,
                isBackground: true,
                rawBytes: validPng,
              ),
              ImageElementModel(
                id: 'fg_img',
                x: 100,
                y: 100,
                width: 150,
                height: 150,
                isBackground: false,
                rawBytes: validPng,
              ),
            ],
            strokes: const [
              StrokeModel(
                id: 'strk_mid',
                points: [
                  Point2D(x: 60, y: 60, timestamp: 0),
                  Point2D(x: 160, y: 160, timestamp: 1),
                ],
                colorValue: 0xFF000000,
                strokeWidth: 3.0,
                opacity: 1.0,
                toolType: ToolType.ballpointPen,
              ),
            ],
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final exportedFile = await ExportService.exportNotebookToPdf(notebook);
      expect(exportedFile, isNotNull);
      expect(await exportedFile!.exists(), isTrue);
      expect(await exportedFile.length(), greaterThan(500));

      try {
        await exportedFile.delete();
      } catch (_) {}
    });

    test('exportNotebookToPdf exports rotated images and multi-line wrapped text elements', () async {
      final validPng = Uint8List.fromList([
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
        0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84,
        120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78,
        68, 174, 66, 96, 130
      ]);

      final notebook = NotebookModel(
        id: 'nb_rotated_and_text',
        title: 'Rotated And Text Test',
        pages: [
          PageModel(
            id: 'page_rot_1',
            pageIndex: 0,
            width: 800,
            height: 1100,
            imageElements: [
              ImageElementModel(
                id: 'rotated_img',
                x: 100,
                y: 100,
                width: 150,
                height: 150,
                rotation: 0.785, // 45 degrees
                rawBytes: validPng,
              ),
            ],
            textElements: const [
              TextElementModel(
                id: 'multiline_txt',
                text: 'Line 1: Title\nLine 2: A very long description that will be wrapped properly across lines without breaking the PDF structure.',
                x: 80,
                y: 300,
                width: 250,
                fontSize: 14,
                colorValue: 0xFF0F172A,
              ),
            ],
          ),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final exportedFile = await ExportService.exportNotebookToPdf(notebook);
      expect(exportedFile, isNotNull);
      expect(await exportedFile!.exists(), isTrue);
      expect(await exportedFile.length(), greaterThan(500));

      try {
        await exportedFile.delete();
      } catch (_) {}
    });
  });
}
