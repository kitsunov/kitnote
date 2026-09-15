import 'package:flutter_test/flutter_test.dart';
import 'package:kitnote/models/notebook_model.dart';
import 'package:kitnote/models/page_model.dart';
import 'package:kitnote/models/page_template_model.dart';
import 'package:kitnote/models/point_model.dart';
import 'package:kitnote/models/stroke_model.dart';
import 'package:kitnote/models/text_element_model.dart';
import 'package:kitnote/models/tool_type.dart';

void main() {
  group('Notebook Serialization Tests', () {
    test('NotebookModel round-trip serialization preserves all nested state', () {
      final original = NotebookModel(
        id: 'nb_test_123',
        title: 'Лекция по физике',
        folderId: 'folder_study',
        createdAt: DateTime(2026, 9, 15, 12, 0),
        updatedAt: DateTime(2026, 9, 15, 14, 30),
        coverColor: 0xFF2563EB,
        tags: ['физика', 'механика'],
        pages: [
          const PageModel(
            id: 'page_0',
            pageIndex: 0,
            template: PageTemplateModel(
              type: PaperTemplateType.cornell,
              colorTheme: PaperColorTheme.ivory,
            ),
            strokes: [
              StrokeModel(
                id: 's1',
                points: [
                  Point2D(x: 10, y: 20, pressure: 0.8, timestamp: 100),
                  Point2D(x: 15, y: 25, pressure: 1.0, timestamp: 120),
                ],
                colorValue: 0xFF000000,
                strokeWidth: 3.0,
                toolType: ToolType.fountainPen,
              ),
            ],
            textElements: [
              TextElementModel(
                id: 't1',
                text: 'Квантовая теория поля',
                x: 100,
                y: 150,
                fontSize: 22,
              ),
            ],
          ),
        ],
      );

      final json = original.toJson();
      final restored = NotebookModel.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.folderId, equals(original.folderId));
      expect(restored.tags, equals(original.tags));
      expect(restored.pages.length, equals(1));

      final restoredPage = restored.pages.first;
      expect(restoredPage.template.type, equals(PaperTemplateType.cornell));
      expect(restoredPage.template.colorTheme, equals(PaperColorTheme.ivory));
      expect(restoredPage.strokes.length, equals(1));
      expect(restoredPage.strokes.first.points.length, equals(2));
      expect(restoredPage.textElements.first.text, equals('Квантовая теория поля'));
    });
  });
}
