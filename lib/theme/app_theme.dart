import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFFF35B28);
  static const Color secondary = Color(0xFF1A237E);
  static const Color background = Color(0xFFF9F9F9);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
  static const Color info = Color(0xFF1976D2);
  static const Color warning = Color(0xFFFFA000);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE0E0E0);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.background,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.card,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'AguDisplay',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'AguDisplay',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'AguDisplay',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.secondary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.secondary,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: AppColors.secondary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.secondary),
        labelLarge: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.error,
        contentTextStyle: TextStyle(
          fontFamily: 'AguDisplay',
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: Colors.grey[500]),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
