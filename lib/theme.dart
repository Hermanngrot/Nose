import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4A90E2);
  static const accent = Color(0xFF50E3C2);
  static const surface = Color(0xFFF8F9FB);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF9AA4B2);
  static const danger = Color(0xFFEB5757);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData.light();
    return base.copyWith(
      primaryColor: AppColors.primary,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        background: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        elevation: 2,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        bodyMedium: const TextStyle(fontSize: 14, color: Colors.black87),
        bodySmall: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}
