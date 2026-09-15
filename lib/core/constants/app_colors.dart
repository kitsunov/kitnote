import 'dart:ui';

class AppColors {
  // Brand / Theme
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const accent = Color(0xFF06B6D4);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF0F172A);
  static const border = Color(0xFFE2E8F0);
  static const borderDark = Color(0xFF334155);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);

  // Pen Palette Presets
  static const penPresets = [
    Color(0xFF0F172A), // Pure Black / Slate 900
    Color(0xFF1E3A8A), // Deep Navy
    Color(0xFF2563EB), // Classic Royal Blue
    Color(0xFF047857), // Forest Green
    Color(0xFFDC2626), // Crimson Red
    Color(0xFF7C3AED), // Purple Violet
    Color(0xFFD97706), // Amber Ochre
    Color(0xFF64748B), // Pencil Graphite Grey
    Color(0xFFEC4899), // Pink
    Color(0xFFFFFFFF), // White (for dark mode paper)
  ];

  // Highlighter Palette Presets (designed for multiply blend mode)
  static const highlighterPresets = [
    Color(0xFFFEF08A), // Classic Highlighter Yellow (translucent)
    Color(0xFFA7F3D0), // Pastel Mint Green
    Color(0xFFBAE6FD), // Pastel Soft Sky Blue
    Color(0xFFFBCFE8), // Pastel Bubblegum Pink
    Color(0xFFFED7AA), // Pastel Peach
    Color(0xFFDDD6FE), // Pastel Lilac
  ];

  // Notebook Cover Colors
  static const coverColors = [
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF0D9488), // Teal Green
    Color(0xFF7C3AED), // Royal Violet
    Color(0xFFBE123C), // Crimson
    Color(0xFFD97706), // Goldenrod
    Color(0xFF334155), // Charcoal Grey
    Color(0xFF047857), // Emerald
    Color(0xFF4338CA), // Indigo
  ];
}
