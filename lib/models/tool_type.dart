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
