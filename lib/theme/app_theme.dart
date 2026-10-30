/// TIS ClassTrack brand theme, taken from the approved mockups.
library;

import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0A3A8C);
  static const navyDark = Color(0xFF082E6E);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFF5B8DEF);
  static const ice = Color(0xFFEAF2FD);
  static const iceDeep = Color(0xFFD7E7FB);
  static const bg = Color(0xFFF4F8FF);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFDCE7F7);
  static const text = Color(0xFF0B2E6E);
  static const textSoft = Color(0xFF5A6E96);
  static const textFaint = Color(0xFF93A3C4);
  static const gold = Color(0xFFF2B01E);
  static const green = Color(0xFF1B7F4B);
  static const red = Color(0xFFC0392B);
  static const amber = Color(0xFFB26A00);
  static const white = Color(0xFFFFFFFF);
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 26.0;
  static const pill = 999.0;
}

double spacing(double n) => n * 4;

class AppShadow {
  static const card = [
    BoxShadow(
      color: Color(0x140A3A8C),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  static const soft = [
    BoxShadow(
      color: Color(0x0F0A3A8C),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];
}

/// Brand fonts: Poppins for the UI, Caveat for the script tagline.
class AppFonts {
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
  static const bold = FontWeight.w700;
  static const extrabold = FontWeight.w800;
  static const scriptFamily = 'Caveat';
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.navy,
    onPrimary: AppColors.white,
    secondary: AppColors.blue,
    onSecondary: AppColors.white,
    surface: AppColors.card,
    onSurface: AppColors.text,
    error: AppColors.red,
    onError: AppColors.white,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Poppins',
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: AppFonts.semibold,
        color: AppColors.text,
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: AppFonts.bold,
        color: AppColors.text,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: AppFonts.semibold,
        color: AppColors.text,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: AppFonts.semibold,
        color: AppColors.text,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: AppFonts.semibold,
        color: AppColors.text,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: AppFonts.regular,
        color: AppColors.text,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: AppFonts.regular,
        color: AppColors.text,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: AppFonts.regular,
        color: AppColors.textSoft,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 15,
        fontWeight: AppFonts.semibold,
        color: AppColors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppColors.textFaint,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
  );
}
