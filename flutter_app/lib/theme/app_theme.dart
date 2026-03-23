import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: FitCityColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: FitCityColors.primary,
        secondary: FitCityColors.primary,
        surface: const Color(0xFF111827),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
        bodyColor: FitCityColors.textPrimary,
        displayColor: FitCityColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: FitCityColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xE60A0E1A),
        selectedItemColor: FitCityColors.primary,
        unselectedItemColor: FitCityColors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
