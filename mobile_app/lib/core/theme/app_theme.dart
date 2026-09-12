import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_constants.dart';

/// Senior Product Designer Theme for HoneyChain Mobile Application
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppConstants.background,
      colorScheme: const ColorScheme.light(
        surface: AppConstants.surface,
        onSurface: AppConstants.textPrimary,
        primary: AppConstants.honeyAccent,
        onPrimary: AppConstants.onPrimary,
        secondary: AppConstants.textSecondary,
        onSecondary: Colors.white,
        onSurfaceVariant: AppConstants.textMuted,
        error: AppConstants.error,
        outline: AppConstants.border,
        primaryContainer: AppConstants.primarySoft,
        onPrimaryContainer: AppConstants.primaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppConstants.surface,
        foregroundColor: AppConstants.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.manrope(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppConstants.textPrimary,
          letterSpacing: -0.6,
          height: 1.2,
        ),
        displayMedium: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppConstants.textPrimary,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppConstants.textPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppConstants.textPrimary,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppConstants.textSecondary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppConstants.textSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppConstants.textPrimary,
          letterSpacing: 0.1,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppConstants.textMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: const TextStyle(
          color: AppConstants.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: AppConstants.textSecondary,
          fontSize: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: AppConstants.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: AppConstants.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: AppConstants.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: AppConstants.error, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppConstants.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          side: const BorderSide(color: AppConstants.border, width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppConstants.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          side: const BorderSide(color: AppConstants.border, width: 1.0),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppConstants.border,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkBackground = Color(0xFF09090B); // Zinc-950
    const darkSurface = Color(0xFF18181B); // Zinc-900 (Cards/Panels)
    const darkTextPrimary = Color(0xFFFAFAFA); // Zinc-50
    const darkTextSecondary = Color(0xFFA1A1AA); // Zinc-400
    const darkTextMuted = Color(0xFF71717A); // Zinc-500
    const darkBorder = Color(0xFF27272A); // Zinc-800
    const darkPrimaryContainer = Color(0xFF27272A); // Zinc-800
    

    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        surface: darkSurface,
        onSurface: darkTextPrimary,
        primary: AppConstants.honeyAccent,
        onPrimary: AppConstants.onPrimary,
        secondary: darkTextSecondary,
        onSecondary: darkTextPrimary,
        onSurfaceVariant: darkTextMuted,
        error: AppConstants.error,
        outline: darkBorder,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: AppConstants.honeyAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.manrope(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: darkTextPrimary,
          letterSpacing: -0.6,
          height: 1.2,
        ),
        displayMedium: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          height: 1.4,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: darkTextSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: 0.1,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: darkTextMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        hintStyle: const TextStyle(
          color: darkTextMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: darkTextSecondary,
          fontSize: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: darkBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: AppConstants.honeyAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: AppConstants.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusSmall),
          borderSide: const BorderSide(color: AppConstants.error, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          side: const BorderSide(color: darkBorder, width: 1.0),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
          side: const BorderSide(color: darkBorder, width: 1.0),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1.0,
        space: 1.0,
      ),
    );
  }
}

/// Extension on BuildContext for clean dynamic theme token retrieval across all widgets
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  Color get scaffoldBg => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get textPrimaryColor => Theme.of(this).colorScheme.onSurface;
  Color get textSecondaryColor => Theme.of(this).colorScheme.secondary;
  Color get textMutedColor => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get borderColor => Theme.of(this).colorScheme.outline;
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  Color get onPrimaryColor => Theme.of(this).colorScheme.onPrimary;
  Color get primarySoftColor => Theme.of(this).colorScheme.primaryContainer;
  Color get primaryDarkColor => Theme.of(this).colorScheme.onPrimaryContainer;
  Color get honeyAccent => AppConstants.honeyAccent;
  Color get errorColor => AppConstants.error;
  Color get successColor => AppConstants.success;
  Color get warningColor => AppConstants.warning;

  /// Brightness-aware tinted backgrounds for status pills/banners.
  /// Light mode uses pastel fills; dark mode uses translucent fills over the
  /// dark surface so badges remain readable without blinding light chips.
  Color get successBgColor =>
      _isDark ? AppConstants.success.withValues(alpha: 0.15) : AppConstants.successBackground;
  Color get errorBgColor =>
      _isDark ? AppConstants.error.withValues(alpha: 0.15) : AppConstants.errorBackground;
  Color get warningBgColor =>
      _isDark ? AppConstants.warning.withValues(alpha: 0.15) : AppConstants.warningBackground;

  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  /// Theme-aware "primary" for icon/text accents: near-black in light mode,
  /// near-white in dark mode (so it never disappears on dark surfaces).
  Color get accentColor =>
      _isDark ? Colors.white : AppConstants.primary;
}

