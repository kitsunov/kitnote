import 'dart:ui';

enum PaperTemplateType {
  blank,
  narrowRuled,
  wideRuled,
  gridSmall,
  gridLarge,
  dotGrid,
  cornell,
  weeklyPlanner,
  musicSheet,
}

enum PaperColorTheme {
  white,
  ivory,
  dark,
  sepia,
  softSage,
}

class PageTemplateModel {
  final PaperTemplateType type;
  final PaperColorTheme colorTheme;
  final double spacing; // grid/line spacing in points
  final double margin; // page margin

  const PageTemplateModel({
    this.type = PaperTemplateType.narrowRuled,
    this.colorTheme = PaperColorTheme.ivory,
    this.spacing = 32.0,
    this.margin = 48.0,
  });

  Color get backgroundColor {
    switch (colorTheme) {
      case PaperColorTheme.white:
        return const Color(0xFFFFFFFF);
      case PaperColorTheme.ivory:
        return const Color(0xFFFAF7EE);
      case PaperColorTheme.dark:
        return const Color(0xFF181A20);
      case PaperColorTheme.sepia:
        return const Color(0xFFF4ECE1);
      case PaperColorTheme.softSage:
        return const Color(0xFFEFF4F0);
    }
  }

  Color get primaryRuleColor {
    if (colorTheme == PaperColorTheme.dark) {
      return const Color(0x22FFFFFF);
    }
    return const Color(0x281E293B);
  }

  Color get accentRuleColor {
    if (colorTheme == PaperColorTheme.dark) {
      return const Color(0x44EF4444);
    }
    return const Color(0x3AEF4444); // Red margin line
  }

  PageTemplateModel copyWith({
    PaperTemplateType? type,
    PaperColorTheme? colorTheme,
    double? spacing,
    double? margin,
  }) {
    return PageTemplateModel(
      type: type ?? this.type,
      colorTheme: colorTheme ?? this.colorTheme,
      spacing: spacing ?? this.spacing,
      margin: margin ?? this.margin,
    );
  }

  Map<String, dynamic> toJson() => {
    't': type.index,
    'c': colorTheme.index,
    's': spacing,
    'm': margin,
  };

  factory PageTemplateModel.fromJson(Map<String, dynamic> json) =>
      PageTemplateModel(
        type: PaperTemplateType.values[json['t'] as int? ?? 1],
        colorTheme: PaperColorTheme.values[json['c'] as int? ?? 1],
        spacing: (json['s'] as num?)?.toDouble() ?? 32.0,
        margin: (json['m'] as num?)?.toDouble() ?? 48.0,
      );
}
