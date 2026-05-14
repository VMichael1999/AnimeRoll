import 'package:flutter/material.dart';

class AppColors {
  static Color bg = const Color(0xFF0D0D14);
  static Color surface = const Color(0xFF16161F);
  static Color surface2 = const Color(0xFF1E1E2E);
  static Color border = const Color(0xFF2A2A3D);
  static Color accent = const Color(0xFF7C3AED);
  static Color accent2 = const Color(0xFFA855F7);
  static const textPrimary = Color(0xFFE2E2F0);
  static const textSecondary = Color(0xFF8888AA);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
}

class AccentPreset {
  final String name;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;

  const AccentPreset({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
  });
}

class AppTheme {
  static const accentPresets = [
    AccentPreset(
      name: 'Violeta',
      primary: Color(0xFF7C3AED),
      secondary: Color(0xFFA855F7),
      background: Color(0xFF0D0D14),
      surface: Color(0xFF16161F),
      surface2: Color(0xFF211333),
      border: Color(0xFF33264A),
    ),
    AccentPreset(
      name: 'Océano',
      primary: Color(0xFF0EA5E9),
      secondary: Color(0xFF38BDF8),
      background: Color(0xFF071218),
      surface: Color(0xFF0C1D26),
      surface2: Color(0xFF102B30),
      border: Color(0xFF1E4654),
    ),
    AccentPreset(
      name: 'Carmesí',
      primary: Color(0xFFEF4444),
      secondary: Color(0xFFF87171),
      background: Color(0xFF13090B),
      surface: Color(0xFF211014),
      surface2: Color(0xFF2F171A),
      border: Color(0xFF4A2429),
    ),
    AccentPreset(
      name: 'Esmeralda',
      primary: Color(0xFF22C55E),
      secondary: Color(0xFF4ADE80),
      background: Color(0xFF07120B),
      surface: Color(0xFF0D1F13),
      surface2: Color(0xFF132A1A),
      border: Color(0xFF23422C),
    ),
    AccentPreset(
      name: 'Ámbar',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFFBBF24),
      background: Color(0xFF120D05),
      surface: Color(0xFF211808),
      surface2: Color(0xFF30240D),
      border: Color(0xFF4A3716),
    ),
    AccentPreset(
      name: 'Rosa',
      primary: Color(0xFFDB2777),
      secondary: Color(0xFFF472B6),
      background: Color(0xFF130711),
      surface: Color(0xFF21101B),
      surface2: Color(0xFF301426),
      border: Color(0xFF4A213A),
    ),
  ];

  static ThemeData get dark => buildDark(0);

  static ThemeData buildDark(int accentIndex) {
    final preset =
        accentPresets[accentIndex.clamp(0, accentPresets.length - 1)];
    AppColors.bg = preset.background;
    AppColors.surface = preset.surface;
    AppColors.surface2 = preset.surface2;
    AppColors.border = preset.border;
    AppColors.accent = preset.primary;
    AppColors.accent2 = preset.secondary;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.dark(
        primary: preset.primary,
        secondary: preset.secondary,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: preset.secondary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.border,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
