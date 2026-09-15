import '../core/l10n/app_strings.dart';

enum ToolType {
  ballpointPen,
  fountainPen,
  brushPen,
  highlighter,
  strokeEraser,
  pixelEraser,
  lasso,
  ruler,
  textBox,
  image,
}

extension ToolTypeExtension on ToolType {
  String localizedName(AppStrings s) {
    switch (this) {
      case ToolType.ballpointPen:
        return s.ballpointPen;
      case ToolType.fountainPen:
        return s.fountainPen;
      case ToolType.brushPen:
        return s.brushPen;
      case ToolType.highlighter:
        return s.highlighter;
      case ToolType.strokeEraser:
        return s.strokeEraser;
      case ToolType.pixelEraser:
        return s.pixelEraser;
      case ToolType.lasso:
        return s.lasso;
      case ToolType.ruler:
        return s.ruler;
      case ToolType.textBox:
        return s.text;
      case ToolType.image:
        return s.photo;
    }
  }

  String get displayName {
    switch (this) {
      case ToolType.ballpointPen:
        return 'Шариковая ручка';
      case ToolType.fountainPen:
        return 'Перьевая ручка';
      case ToolType.brushPen:
        return 'Кисть';
      case ToolType.highlighter:
        return 'Текстовыделитель';
      case ToolType.strokeEraser:
        return 'Штриховой ластик';
      case ToolType.pixelEraser:
        return 'Пиксельный ластик';
      case ToolType.lasso:
        return 'Лассо';
      case ToolType.ruler:
        return 'Линейка';
      case ToolType.textBox:
        return 'Текст';
      case ToolType.image:
        return 'Изображение';
    }
  }

  bool get isPen =>
      this == ToolType.ballpointPen ||
      this == ToolType.fountainPen ||
      this == ToolType.brushPen;

  bool get isEraser =>
      this == ToolType.strokeEraser || this == ToolType.pixelEraser;
}
