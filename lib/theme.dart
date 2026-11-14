import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// shadcn/ui "zinc" palette.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFFAFAFA);
  static const foreground = Color(0xFF09090B);
  static const muted = Color(0xFFF4F4F5);
  static const mutedForeground = Color(0xFF71717A);
  static const border = Color(0xFFE4E4E7);
  static const borderStrong = Color(0xFFD4D4D8);
  static const primary = Color(0xFF18181B);
  static const primaryHover = Color(0xFF27272A);
  static const primaryForeground = Color(0xFFFAFAFA);
  static const destructive = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);

  static const chartPalette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF0D9488),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];
}

class AppRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
}

class AppText {
  static const title = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.foreground,
      height: 1.3,
      letterSpacing: -0.1);
  static const body =
      TextStyle(fontSize: 14.5, color: AppColors.foreground, height: 1.6);
  static const muted =
      TextStyle(fontSize: 12.5, color: AppColors.mutedForeground, height: 1.4);
  static const small =
      TextStyle(fontSize: 12, color: AppColors.mutedForeground, height: 1.3);
  static const label = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: AppColors.mutedForeground,
      letterSpacing: 0.2);

  static TextStyle mono(
          {double size = 12,
          Color color = AppColors.mutedForeground,
          FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.muted,
      onSecondary: AppColors.foreground,
      surface: AppColors.background,
      onSurface: AppColors.foreground,
      error: AppColors.destructive,
      outline: AppColors.border,
    ),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.border,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.foreground, displayColor: AppColors.foreground),
    textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.foreground,
        selectionColor: Color(0x332563EB)),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      textStyle:
          const TextStyle(color: AppColors.primaryForeground, fontSize: 12),
    ),
  );
}
