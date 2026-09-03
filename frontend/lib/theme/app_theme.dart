import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for Traffic Jam, derived from the Figma Dev-Mode tokens.
/// Every screen and widget MUST consume these — do not hardcode colors/fonts.

// ─────────────────────────────────────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Navy / indigo backgrounds
  static const Color bgDeepest = Color(0xFF070C3E); // consultation gradient start
  static const Color bgDeep = Color(0xFF141A4A); // progress track, deep panels
  static const Color bg = Color(0xFF1B2150); // scaffold base (top of gradient)
  static const Color bgBottom = Color(0xFF12173D); // scaffold gradient bottom
  static const Color bodyIndigo = Color(0xFF2A3369); // Figma body fill (rgb 42,51,105)

  // Surfaces
  static const Color surface = Color(0xFF1F2555); // card fill (rendered translucent)
  static const Color surfaceRaised = Color(0xFF2B346B); // nested surfaces (rgb 43,52,107)
  static const Color surfaceRaised2 = Color(0xFF374182); // table headers / chips
  static const Color surfaceRaised3 = Color(0xFF3A4585);
  static const Color navBarBase = Color(0xFF212859); // app bar / bottom nav (rgb 33,40,89)

  // Gold / amber accent family
  static const Color gold = Color(0xFFFFC121); // brand gold — logo, nav-active, FAB
  static const Color amber = Color(0xFFFFC107); // labels, panchang values, accents
  static const Color goldButton = Color(0xFFFFB300); // primary button fill
  static const Color goldLight = Color(0xFFFFD154);
  static const Color goldLighter = Color(0xFFFFE082);
  static const Color orange = Color(0xFFFB923C); // vibe-meter gradient end

  // Text
  static const Color textPrimary = Color(0xFFF5F5F7); // near-white headings/body
  static const Color textOnLight = Color(0xFFF3F4F6);
  static const Color textMuted = Color(0xFF94A3B8); // slate secondary
  static const Color textTan = Color(0xFFD4C5AC); // nav inactive, warm muted
  static const Color textCream = Color(0xFFECE1D1);
  static const Color textOnGold = Color(0xFF432C00); // dark brown on gold buttons

  // Status
  static const Color critical = Color(0xFF93000A); // Rahu Kaal critical badge
  static const Color criticalBg = Color(0xFFFFDAD6);
  static const Color criticalText = Color(0xFFFFB4AB);
  static const Color success = Color(0xFF4ADE80);

  // Lines / borders (used as .withValues(alpha:) at call sites where noted)
  static const Color borderFaint = Color(0x14FFFFFF); // white 8%
  static const Color borderSoft = Color(0x1AFFFFFF); // white 10%
  static const Color goldBorderSoft = Color(0x1AFFC121); // gold 10%

  // Gradients
  static const LinearGradient scaffoldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bg, bgBottom],
  );
  static const LinearGradient goldMeter = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [amber, orange],
  );
  static const LinearGradient goldButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [goldLight, goldButton],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SPACING & RADII
// ─────────────────────────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double section = 32;
  static const double screenH = 24; // horizontal screen padding
  static const double cardPad = 25;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY — Fraunces (logo), Libre Caslon Text (serif headings),
// Inter (body/labels), Geist (nav labels)
// ─────────────────────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  /// Serif display/heading font — Libre Caslon Text
  static TextStyle serif({
    double size = 24,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.libreCaslonText(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Body/label font — Inter
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Brand logo font — Fraunces. Bundled as a local asset (see pubspec.yaml)
  /// rather than GoogleFonts.fraunces()'s runtime network fetch — this one
  /// is the first text a cold-started app paints (splash screen title), so
  /// the fetch-then-swap flash was the most visible possible place for it.
  static TextStyle logoFont({
    double size = 18,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.gold,
    double letterSpacing = 1.8,
  }) =>
      TextStyle(
        fontFamily: 'Fraunces',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Bottom-nav label font — Geist
  static TextStyle navFont({
    double size = 10,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textTan,
    double letterSpacing = 0.5,
  }) =>
      GoogleFonts.geist(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // ── Named convenience styles ──────────────────────────────────────────────
  // Serif headings
  static TextStyle get displayXl =>
      serif(size: 40, weight: FontWeight.w700, height: 1.1);
  static TextStyle get displayLg =>
      serif(size: 28, weight: FontWeight.w700, height: 36 / 28); // "Tuesday, May 14"
  static TextStyle get headingSerif =>
      serif(size: 24, weight: FontWeight.w400, height: 32 / 24); // section titles
  static TextStyle get serifValue => serif(
      size: 24, weight: FontWeight.w400, color: AppColors.amber, height: 32 / 24);

  // Inter labels / body
  static TextStyle get sectionLabel => sans(
      size: 12,
      weight: FontWeight.w500,
      color: AppColors.amber,
      letterSpacing: 1.2,
      height: 16 / 12); // "TODAY'S PANCHANG"
  static TextStyle get microLabel => sans(
      size: 12,
      weight: FontWeight.w500,
      color: AppColors.textMuted,
      letterSpacing: 0.96,
      height: 16 / 12); // "TITHI"
  static TextStyle get cardTitle => sans(
      size: 14, weight: FontWeight.w600, letterSpacing: 0.7, height: 20 / 14);
  static TextStyle get body => sans(
      size: 16,
      weight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 24 / 16);
  static TextStyle get bodySmall => sans(
      size: 13,
      weight: FontWeight.w400,
      color: AppColors.textMuted,
      height: 18 / 13);
  static TextStyle get button => sans(
      size: 16,
      weight: FontWeight.w600,
      color: AppColors.textOnGold,
      height: 24 / 16);

  // Nav
  static TextStyle get navLabel =>
      navFont(size: 10, letterSpacing: 0.5).copyWith(height: 15 / 10);
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.gold,
      secondary: AppColors.amber,
      onPrimary: AppColors.textOnGold,
      onSurface: AppColors.textPrimary,
      error: AppColors.critical,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
