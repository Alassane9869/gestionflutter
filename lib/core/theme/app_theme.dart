import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeColor {
  blue(Color(0xFF635BFF), "Bleu SaaS"),
  orange(Color(0xFFF97316), "Orange Vibrant"),
  green(Color(0xFF10B981), "Vert Émeraude"),
  purple(Color(0xFF8B5CF6), "Violet Profond"),
  red(Color(0xFFEF4444), "Rouge Passion"),
  teal(Color(0xFF0D9488), "Turquoise Neon"),
  pink(Color(0xFFDB2777), "Rose Premium"),
  grey(Color(0xFF4B5563), "Gris Carbone");

  final Color color;
  final String label;
  const AppThemeColor(this.color, this.label);
}

class AppTheme {
  // Couleurs de statut
  static const successClr = Color(0xFF10B981);
  static const warningClr = Color(0xFFF59E0B);
  static const errorClr = Color(0xFFEF4444);
  static const infoClr = Color(0xFF3B82F6);

  static ThemeData getTheme(AppThemeColor themeColor, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return _buildDark(themeColor.color);
    } else {
      return _buildLight(themeColor.color);
    }
  }

  static BoxDecoration strictBorder(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E2128) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isDark ? const Color(0xFF2D3039) : const Color(0xFFE5E7EB),
        width: 1,
      ),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final baseContext = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.interTextTheme(baseContext).copyWith(
      displayLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
      ),
      displaySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w400,
        color: brightness == Brightness.light
            ? const Color(0xFF374151)
            : const Color(0xFFD1D5DB),
      ),
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w500),
    );
  }

  static ThemeData _buildDark(Color primaryClr) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0E1015),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryClr,
        brightness: Brightness.dark,
        primary: primaryClr,
        secondary: const Color(0xFF1E2128),
        surface: const Color(0xFF1E2128),
        error: errorClr,
        tertiary: successClr,
      ),
      textTheme: _buildTextTheme(Brightness.dark).copyWith(
        bodyLarge: GoogleFonts.inter(color: const Color(0xFFE5E7EB)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF9CA3AF)),
        titleMedium: GoogleFonts.inter(
          color: const Color(0xFFF9FAFB),
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2D3039), width: 1),
        ),
        color: const Color(0xFF1E2128),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0E1015),
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryClr,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE5E7EB),
          side: const BorderSide(color: Color(0xFF374151)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF16181D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2D3039), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2D3039), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: primaryClr, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2D3039),
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData _buildLight(Color primaryClr) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F9FC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryClr,
        brightness: Brightness.light,
        primary: primaryClr,
        secondary: const Color(0xFFF3F4F6),
        surface: const Color(0xFFFFFFFF),
        error: errorClr,
        tertiary: successClr,
      ),
      textTheme: _buildTextTheme(Brightness.light).copyWith(
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF111827)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF4B5563)),
        titleMedium: GoogleFonts.inter(
          color: const Color(0xFF111827),
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        color: Colors.white,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        foregroundColor: Color(0xFF111827),
        centerTitle: false,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryClr,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF374151),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: primaryClr, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
