import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color palette — Spotify-inspired dark theme with green accent.
class AppColors {
  // Core surfaces
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceHighlight = Color(0xFF282828);
  static const Color surfaceElevated = Color(0xFF333333);

  // Brand green
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryDark = Color(0xFF158A3E);
  static const Color primaryLight = Color(0xFF2EE672);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF535353);

  // Accents & states
  static const Color error = Color(0xFFE2534C);
  static const Color warning = Color(0xFFFFC107);
  static const Color heart = Color(0xFFE91E63);

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHighlight = Color(0xFFEEEEEE);
  static const Color lightTextPrimary = Color(0xFF121212);
  static const Color lightTextSecondary = Color(0xFF535353);
}

/// Durations used across the app for consistent micro-animations.
class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
}

class AppTheme {
  static ThemeData get darkTheme => _build(Brightness.dark);
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.background : AppColors.lightBackground;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final surfaceH = isDark ? AppColors.surfaceHighlight : AppColors.lightSurfaceHighlight;
    final textPrimary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.black,
        secondary: AppColors.primaryLight,
        onSecondary: Colors.black,
        error: AppColors.error,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      // Google Fonts — Outfit is clean & modern, similar to Spotify's Circular
      textTheme: GoogleFonts.outfitTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
          headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
          headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 20),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
          bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: textSecondary, fontSize: 12),
          labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          labelSmall: TextStyle(color: textSecondary, fontSize: 11),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: textPrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: surfaceH,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: isDark ? Colors.white24 : Colors.black26,
        thumbColor: AppColors.primary,
        overlayShape: SliderComponentShape.noOverlay,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white : Colors.black12,
        hintStyle: TextStyle(color: isDark ? Colors.black54 : Colors.black38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceH,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.outfit(fontSize: 13, color: textPrimary),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
    );
  }
}
