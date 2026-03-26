import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Icon's vivid blue + sporty green accent
  static const Color _seedColor   = Color(0xFF2196F3);
  static const Color _accentGreen = Color(0xFF43A047);

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return _build(cs);
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return _build(cs);
  }

  static ThemeData _build(ColorScheme cs) {
    final base = ThemeData(useMaterial3: true, colorScheme: cs);

    return base.copyWith(
      // ── Typography ───────────────────────────────────────────────────
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
        // Slightly bolder headings for a sporty feel
        headlineLarge:  GoogleFonts.nunito(
            fontWeight: FontWeight.w800, color: cs.onSurface),
        headlineMedium: GoogleFonts.nunito(
            fontWeight: FontWeight.w800, color: cs.onSurface),
        headlineSmall:  GoogleFonts.nunito(
            fontWeight: FontWeight.w700, color: cs.onSurface),
        titleLarge:     GoogleFonts.nunito(
            fontWeight: FontWeight.w700, color: cs.onSurface),
        titleMedium:    GoogleFonts.nunito(
            fontWeight: FontWeight.w600, color: cs.onSurface),
        titleSmall:     GoogleFonts.nunito(
            fontWeight: FontWeight.w600, color: cs.onSurface),
      ),

      // ── AppBar ───────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: cs.onPrimary,
        ),
        iconTheme: IconThemeData(color: cs.onPrimary),
        actionsIconTheme: IconThemeData(color: cs.onPrimary),
        systemOverlayStyle: cs.brightness == Brightness.light
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      // ── Cards ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 2,
        surfaceTintColor: cs.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // ── Chips ────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ── Filled buttons ───────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.nunito(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      // ── Outlined buttons ─────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.nunito(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── FAB ──────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Input fields ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: cs.surfaceContainerLowest,
      ),

      // ── ListTile ─────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),

      // ── TabBar (sits inside coloured AppBar) ─────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: cs.onPrimary,
        unselectedLabelColor: cs.onPrimary.withOpacity(0.6),
        indicatorColor: cs.onPrimary,
        labelStyle: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w500),
      ),

      // ── Divider ──────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
