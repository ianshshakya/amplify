import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central color palette — Premium Spotify-inspired dark theme
class AppColors {
  // Core surfaces
  static const Color background = Color(0xFF000000); // Deep black
  static const Color surface = Color(0xFF121212); // Slightly elevated
  static const Color surfaceHighlight = Color(0xFF282828);
  static const Color surfaceElevated = Color(0xFF333333);

  // Brand Accent (Spotify-like Green)
  static const Color primary = Color.fromARGB(255, 22, 166, 161);
  static const Color primaryDark = Color.fromARGB(255, 40, 178, 169);
  static const Color primaryLight =
      Color.fromARGB(255, 25, 209, 194); // Brighter hover/active state

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA7A7A7); // Softer grey
  static const Color textDisabled = Color(0xFF535353);

  // Accents & states
  static const Color error = Color(0xFFE91429);
  static const Color warning = Color(0xFFFFA42B);
  static const Color heart = Color(0xFF1DB954); // Green for liked

  // Light theme surfaces (if supported, though we focus on dark)
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF6F6F6);
  static const Color lightSurfaceHighlight = Color(0xFFEBEBEB);
  static const Color lightTextPrimary = Color(0xFF000000);
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
    final surfaceH =
        isDark ? AppColors.surfaceHighlight : AppColors.lightSurfaceHighlight;
    final textPrimary =
        isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

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
      // Inter provides that clean, geometric, highly legible look
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          displayLarge: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0),
          displayMedium: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5),
          displaySmall:
              TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 32,
              letterSpacing: -0.5),
          headlineMedium: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              letterSpacing: -0.5),
          headlineSmall: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.5),
          titleLarge: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
          titleMedium: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          titleSmall: TextStyle(
              color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
          bodyLarge: TextStyle(
              color: textPrimary, fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(
              color: textPrimary, fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(
              color: textSecondary, fontSize: 13, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
          labelSmall: TextStyle(
              color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.black.withOpacity(0.9), // Glass-like base
        selectedItemColor: textPrimary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: textPrimary,
        inactiveTrackColor: isDark ? const Color(0xFF4D4D4D) : Colors.black26,
        thumbColor: textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(
              color: isDark ? const Color(0xFF727272) : Colors.black26,
              width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceH,
        hintStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceH,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(
            fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
