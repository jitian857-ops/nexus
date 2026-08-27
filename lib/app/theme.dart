import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'motion.dart';

class NexusPalette {
  const NexusPalette({
    required this.id,
    required this.label,
    required this.swatch,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.card,
    required this.cardTop,
    required this.navBar,
    required this.cyan,
    required this.cyanMuted,
    required this.purple,
    required this.periwinkle,
    required this.green,
    required this.gold,
    required this.income,
    required this.expense,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.hairline,
    required this.pageTop,
    required this.frame,
  });

  final String id;
  final String label;
  final Color swatch;
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color card;
  final Color cardTop;
  final Color navBar;
  final Color cyan;
  final Color cyanMuted;
  final Color purple;
  final Color periwinkle;
  final Color green;
  final Color gold;
  final Color income;
  final Color expense;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color hairline;
  final Color pageTop;
  final Color frame;

  bool get isLight => brightness == Brightness.light;

  List<Color> get accentSweep => [cyan, periwinkle, purple];

  static const midnight = NexusPalette(
    id: 'midnight',
    label: 'ミッドナイト',
    swatch: Color(0xFF00D4FF),
    brightness: Brightness.dark,
    background: Color(0xFF05070E),
    surface: Color(0xFF0B1018),
    card: Color(0xFF101722),
    cardTop: Color(0xFF222C3C),
    navBar: Color(0xD10A0E16),
    cyan: Color(0xFF00D4FF),
    cyanMuted: Color(0xFF5AA8C4),
    purple: Color(0xFF9B6BFF),
    periwinkle: Color(0xFF7C9CFF),
    green: Color(0xFF3DFF8A),
    gold: Color(0xFFC4B7A0),
    income: Color(0xFF3DFF8A),
    expense: Color(0xFFFF5B7A),
    text: Color(0xFFF4F1EA),
    textSecondary: Color(0xFF8B9BB4),
    textMuted: Color(0xFF5C6B82),
    border: Color(0xFF243040),
    hairline: Color(0x28FFFFFF),
    pageTop: Color(0xFF070B14),
    frame: Color(0xFF020308),
  );

  static const ivory = NexusPalette(
    id: 'ivory',
    label: 'アイボリー',
    swatch: Color(0xFFF6F1E8),
    brightness: Brightness.light,
    background: Color(0xFFF6F1E8),
    surface: Color(0xFFFFFBF4),
    card: Color(0xFFFFFFFF),
    cardTop: Color(0xFFFFF8EC),
    navBar: Color(0xF2FFFFFF),
    cyan: Color(0xFF0A8CA8),
    cyanMuted: Color(0xFF4E8EA0),
    purple: Color(0xFF7A4FE0),
    periwinkle: Color(0xFF5B74D6),
    green: Color(0xFF1F9A58),
    gold: Color(0xFF9A7B3C),
    income: Color(0xFF1F9A58),
    expense: Color(0xFFD6455D),
    text: Color(0xFF1C2430),
    textSecondary: Color(0xFF5B6573),
    textMuted: Color(0xFF8A93A0),
    border: Color(0xFFE4D9C8),
    hairline: Color(0x33000000),
    pageTop: Color(0xFFFFF8EE),
    frame: Color(0xFFE8DFD2),
  );

  static const crimson = NexusPalette(
    id: 'crimson',
    label: 'クリムゾン',
    swatch: Color(0xFFFF4D6A),
    brightness: Brightness.dark,
    background: Color(0xFF12060A),
    surface: Color(0xFF1A0B10),
    card: Color(0xFF241018),
    cardTop: Color(0xFF3A1824),
    navBar: Color(0xD1160A0E),
    cyan: Color(0xFFFF6B81),
    cyanMuted: Color(0xFFC47A86),
    purple: Color(0xFFFF8FA0),
    periwinkle: Color(0xFFFFB4A2),
    green: Color(0xFFFFC857),
    gold: Color(0xFFE8C9A0),
    income: Color(0xFF7DFFB3),
    expense: Color(0xFFFF4D6A),
    text: Color(0xFFFFF0F2),
    textSecondary: Color(0xFFC9A8AE),
    textMuted: Color(0xFF8E6A72),
    border: Color(0xFF4A2230),
    hairline: Color(0x33FF8FA0),
    pageTop: Color(0xFF1A080E),
    frame: Color(0xFF0A0306),
  );

  static const forest = NexusPalette(
    id: 'forest',
    label: 'フォレスト',
    swatch: Color(0xFF3DFF8A),
    brightness: Brightness.dark,
    background: Color(0xFF06110C),
    surface: Color(0xFF0B1812),
    card: Color(0xFF10241A),
    cardTop: Color(0xFF1B3A2A),
    navBar: Color(0xD1081610),
    cyan: Color(0xFF5CFFB0),
    cyanMuted: Color(0xFF6AAF8C),
    purple: Color(0xFFA6E08A),
    periwinkle: Color(0xFF7CDBB0),
    green: Color(0xFF3DFF8A),
    gold: Color(0xFFD7C48A),
    income: Color(0xFF3DFF8A),
    expense: Color(0xFFFF7A6A),
    text: Color(0xFFEEF8F1),
    textSecondary: Color(0xFF9BB8A8),
    textMuted: Color(0xFF6A8778),
    border: Color(0xFF244033),
    hairline: Color(0x283DFF8A),
    pageTop: Color(0xFF08160F),
    frame: Color(0xFF030A07),
  );

  static const ocean = NexusPalette(
    id: 'ocean',
    label: 'オーシャン',
    swatch: Color(0xFF3DA9FC),
    brightness: Brightness.dark,
    background: Color(0xFF061018),
    surface: Color(0xFF0B1822),
    card: Color(0xFF102230),
    cardTop: Color(0xFF1A3448),
    navBar: Color(0xD108141C),
    cyan: Color(0xFF4ECBFF),
    cyanMuted: Color(0xFF6A9BB4),
    purple: Color(0xFF6B8CFF),
    periwinkle: Color(0xFF7C9CFF),
    green: Color(0xFF5CFFD4),
    gold: Color(0xFFC4B7A0),
    income: Color(0xFF5CFFD4),
    expense: Color(0xFFFF6B8A),
    text: Color(0xFFECF6FF),
    textSecondary: Color(0xFF8AABC0),
    textMuted: Color(0xFF5C7A8E),
    border: Color(0xFF244056),
    hairline: Color(0x284ECBFF),
    pageTop: Color(0xFF08141C),
    frame: Color(0xFF03080C),
  );

  static const sunset = NexusPalette(
    id: 'sunset',
    label: 'サンセット',
    swatch: Color(0xFFFF7A4D),
    brightness: Brightness.dark,
    background: Color(0xFF140A06),
    surface: Color(0xFF1C100A),
    card: Color(0xFF26160E),
    cardTop: Color(0xFF3C2416),
    navBar: Color(0xD1180E08),
    cyan: Color(0xFFFF9A5C),
    cyanMuted: Color(0xFFC4926A),
    purple: Color(0xFFFF6B8A),
    periwinkle: Color(0xFFFFC857),
    green: Color(0xFFFFB86B),
    gold: Color(0xFFFFC857),
    income: Color(0xFF7DFFB3),
    expense: Color(0xFFFF5B7A),
    text: Color(0xFFFFF4EA),
    textSecondary: Color(0xFFC8B09A),
    textMuted: Color(0xFF8E7460),
    border: Color(0xFF4A3020),
    hairline: Color(0x33FF9A5C),
    pageTop: Color(0xFF1A0E08),
    frame: Color(0xFF0A0603),
  );

  static const sakura = NexusPalette(
    id: 'sakura',
    label: 'サクラ',
    swatch: Color(0xFFFF8AD2),
    brightness: Brightness.light,
    background: Color(0xFFFFF2F6),
    surface: Color(0xFFFFF7FA),
    card: Color(0xFFFFFFFF),
    cardTop: Color(0xFFFFE8F0),
    navBar: Color(0xF2FFFFFF),
    cyan: Color(0xFFE0569B),
    cyanMuted: Color(0xFFC47A9A),
    purple: Color(0xFFB44AD4),
    periwinkle: Color(0xFFFF8AD2),
    green: Color(0xFF2EAA72),
    gold: Color(0xFFB8894A),
    income: Color(0xFF2EAA72),
    expense: Color(0xFFE04560),
    text: Color(0xFF3A2430),
    textSecondary: Color(0xFF7A5A68),
    textMuted: Color(0xFFA88894),
    border: Color(0xFFF0D0DC),
    hairline: Color(0x33E0569B),
    pageTop: Color(0xFFFFF7FA),
    frame: Color(0xFFF3D8E2),
  );

  static const all = [midnight, ivory, crimson, forest, ocean, sunset, sakura];

  static NexusPalette byId(String? id) {
    for (final palette in all) {
      if (palette.id == id) return palette;
    }
    return midnight;
  }
}

class NexusColors {
  NexusColors._();

  static NexusPalette _active = NexusPalette.midnight;

  static NexusPalette get active => _active;

  static void apply(NexusPalette palette) => _active = palette;

  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get card => _active.card;
  static Color get cardTop => _active.cardTop;
  static Color get navBar => _active.navBar;
  static Color get cyan => _active.cyan;
  static Color get cyanMuted => _active.cyanMuted;
  static Color get purple => _active.purple;
  static Color get periwinkle => _active.periwinkle;
  static Color get green => _active.green;
  static Color get gold => _active.gold;
  static Color get income => _active.income;
  static Color get expense => _active.expense;
  static Color get text => _active.text;
  static Color get textSecondary => _active.textSecondary;
  static Color get textMuted => _active.textMuted;
  static Color get border => _active.border;
  static Color get hairline => _active.hairline;
  static Color get pageTop => _active.pageTop;
  static Color get frame => _active.frame;
  static List<Color> get accentSweep => _active.accentSweep;
  static bool get isLight => _active.isLight;

  static const double cardRadius = 26;

  static const List<Color> boxPalette = [
    Color(0xFF3DA9FC),
    Color(0xFF9B6BFF),
    Color(0xFF00D4FF),
    Color(0xFF3DFF8A),
    Color(0xFFFFC857),
    Color(0xFFFF8AD2),
    Color(0xFFFF7A4D),
    Color(0xFFFF5B7A),
    Color(0xFF7C9CFF),
    Color(0xFF2EE6C7),
    Color(0xFFC77DFF),
  ];
}

class NexusTheme {
  NexusTheme._();

  static ThemeData of(NexusPalette palette) {
    NexusColors.apply(palette);
    final isLight = palette.isLight;
    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.cyan,
      secondary: palette.purple,
      surface: palette.surface,
      error: palette.expense,
      onPrimary: isLight ? Colors.white : Colors.black,
      onSecondary: isLight ? Colors.white : Colors.white,
      onSurface: palette.text,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.cyan.withValues(alpha: isLight ? 0.16 : 0.22),
          foregroundColor: palette.cyan,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: palette.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.cyan.withValues(alpha: 0.22),
        labelStyle: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: palette.border.withValues(alpha: 0.8)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.cyan,
        thumbColor: palette.cyan,
      ),
    );

    final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme).apply(
      bodyColor: palette.textSecondary,
      displayColor: palette.text,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values) platform: const NexusPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get dark => of(NexusPalette.midnight);
}
