import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color veriflammeRed = Color(0xFFD32F2F);
  static const Color veriflammeRedLight = Color(0xFFFFEBEE);
  static const Color sauvdefibGreen = Color(0xFF2E7D32);
  static const Color sauvdefibGreenLight = Color(0xFFE8F5E9);

  // Status Colors
  static const Color warningOrange = Color(0xFFF57C00);
  static const Color warningOrangeLight = Color(0xFFFFF3E0);
  static const Color infoBlue = Color(0xFF1976D2);
  static const Color infoBlueLight = Color(0xFFE3F2FD);
  static const Color successGreen = Color(0xFF43A047);

  // Neutral Colors
  static const Color primaryText = Color(0xFF1E293B);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color tertiaryText = Color(0xFF94A3B8);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Primary brand
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF334155);

  // Responsive breakpoints
  static const double mobileBreakpoint = 768;
  static const double tabletBreakpoint = 1200;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: veriflammeRed,
        tertiary: sauvdefibGreen,
        surface: surface,
        error: veriflammeRed,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.w500, fontSize: 14),
        bodyLarge: GoogleFonts.inter(color: primaryText, fontSize: 16),
        bodyMedium: GoogleFonts.inter(color: secondaryText, fontSize: 14),
        bodySmall: GoogleFonts.inter(color: tertiaryText, fontSize: 12),
        labelLarge: GoogleFonts.inter(color: primaryText, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primaryText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: primaryText),
        titleTextStyle: GoogleFonts.inter(
          color: primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: veriflammeRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.inter(color: secondaryText),
        hintStyle: GoogleFonts.inter(color: tertiaryText),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: secondaryText,
        indicatorColor: primary,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
      ),
    );
  }

  // Helper to get branch color
  static Color branchColor(String branch) {
    return branch == 'VERIFLAMME' ? veriflammeRed : sauvdefibGreen;
  }

  static Color branchColorLight(String branch) {
    return branch == 'VERIFLAMME' ? veriflammeRedLight : sauvdefibGreenLight;
  }

  static IconData branchIcon(String branch) {
    return branch == 'VERIFLAMME' ? Icons.local_fire_department : Icons.medical_services;
  }

  // Card decoration helper
  static BoxDecoration cardDecoration({Color? accentColor}) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: cardBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
