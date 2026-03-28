import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand colours ──────────────────────────────────────
  static const Color _darkBg = Color(0xFF0A0E1A);
  static const Color _darkSurface = Color(0xFF111827);
  static const Color _darkCard = Color(0xFF1C2333);
  static const Color _accent = Color(0xFF00D4FF);
  static const Color _accentGreen = Color(0xFF00E676);
  static const Color _accentRed = Color(0xFFFF5252);

  static const Color _lightBg = Color(0xFFF0F4FF);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF3D5AF1);

  // ── Dark Theme ──────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _darkBg,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _accentGreen,
          error: _accentRed,
          surface: _darkSurface,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardThemeData(
          color: _darkCard,
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _darkBg,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 48,
          titleTextStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: Colors.white, size: 20),
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minVerticalPadding: 4,
        ),
        drawerTheme: const DrawerThemeData(backgroundColor: _darkSurface, width: 260),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? _accent : Colors.grey),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? _accent.withValues(alpha: .4)
                  : Colors.grey.withValues(alpha: .3)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.black,
            minimumSize: const Size(64, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          fillColor: _darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        extensions: const [AppColors.dark],
      );

  // ── Light Theme ─────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _lightBg,
        colorScheme: const ColorScheme.light(
          primary: _primary,
          secondary: _accentGreen,
          error: _accentRed,
          surface: _lightSurface,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        cardTheme: CardThemeData(
          color: _lightSurface,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _lightSurface,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 48,
          titleTextStyle: GoogleFonts.inter(
            color: const Color(0xFF1A1A2E),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1A1A2E), size: 20),
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minVerticalPadding: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 36),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        extensions: const [AppColors.light],
      );
}

// ── Custom theme extension for extra named colours ──────────
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color accent;
  final Color accentGreen;
  final Color accentRed;
  final Color accentOrange;
  final Color card;
  final Color surface;

  const AppColors({
    required this.accent,
    required this.accentGreen,
    required this.accentRed,
    required this.accentOrange,
    required this.card,
    required this.surface,
  });

  static const dark = AppColors(
    accent: Color(0xFF00D4FF),
    accentGreen: Color(0xFF00E676),
    accentRed: Color(0xFFFF5252),
    accentOrange: Color(0xFFFF9800),
    card: Color(0xFF1C2333),
    surface: Color(0xFF111827),
  );

  static const light = AppColors(
    accent: Color(0xFF3D5AF1),
    accentGreen: Color(0xFF2E7D32),
    accentRed: Color(0xFFD32F2F),
    accentOrange: Color(0xFFE65100),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF0F4FF),
  );

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentGreen,
    Color? accentRed,
    Color? accentOrange,
    Color? card,
    Color? surface,
  }) =>
      AppColors(
        accent: accent ?? this.accent,
        accentGreen: accentGreen ?? this.accentGreen,
        accentRed: accentRed ?? this.accentRed,
        accentOrange: accentOrange ?? this.accentOrange,
        card: card ?? this.card,
        surface: surface ?? this.surface,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentRed: Color.lerp(accentRed, other.accentRed, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
    );
  }
}
