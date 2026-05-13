import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0D0D14);
  static const surface = Color(0xFF16161F);
  static const surface2 = Color(0xFF1E1E2E);
  static const border = Color(0xFF2A2A3D);
  static const accent = Color(0xFF7C3AED);
  static const accent2 = Color(0xFFA855F7);
  static const textPrimary = Color(0xFFE2E2F0);
  static const textSecondary = Color(0xFF8888AA);
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accent2,
          surface: AppColors.surface,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
          titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          labelSmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surface2,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accent2,
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
