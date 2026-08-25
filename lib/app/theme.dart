import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NexusColors {
  NexusColors._();

  static const Color background = Color(0xFF080A10);
  static const Color surface = Color(0xFF0E1218);
  static const Color card = Color(0xFF121820);
  static const Color cardTop = Color(0xFF1A212C);
  static const Color navBar = Color(0xCC0C1016);

  static const Color cyan = Color(0xFF00D4FF);
  static const Color cyanMuted = Color(0xFF5AA8C4);
  static const Color purple = Color(0xFF9B6BFF);
  static const Color green = Color(0xFF3DFF8A);
  static const Color gold = Color(0xFFC4B7A0);
  static const Color income = Color(0xFF3DFF8A);
  static const Color expense = Color(0xFFFF5B7A);

  static const Color text = Color(0xFFF4F1EA);
  static const Color textSecondary = Color(0xFF8B9BB4);
  static const Color textMuted = Color(0xFF5C6B82);
  static const Color border = Color(0xFF243040);
  static const Color hairline = Color(0x28FFFFFF);

  static const double cardRadius = 22;
}

class NexusTheme {
  NexusTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: NexusColors.cyan,
      secondary: NexusColors.purple,
      surface: NexusColors.surface,
      error: NexusColors.expense,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: NexusColors.text,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: NexusColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NexusColors.cyan.withValues(alpha: 0.18),
          foregroundColor: NexusColors.cyan,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NexusColors.textSecondary,
          side: BorderSide(color: NexusColors.border.withValues(alpha: 0.9)),
        ),
      ),
    );

    final textTheme = GoogleFonts.notoSansJpTextTheme(base.textTheme).apply(
      bodyColor: NexusColors.textSecondary,
      displayColor: NexusColors.text,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }
}
