import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  // Colors from the screenshot/requirements
  static const Color _background = AppConstants.colorBackground;
  static const Color _cardBackground = AppConstants.colorCardBackground;
  static const Color _primary = AppConstants.colorPrimary;
  static const Color _textPrimary = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _primary),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        surface: _cardBackground,
        onSurface: _textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: _textPrimary, displayColor: _textPrimary),
      cardTheme: const CardTheme(
        color: _cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _textPrimary,
        ),
        iconTheme: IconThemeData(color: _primary),
      ),
      iconTheme: const IconThemeData(color: _primary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _background,
        indicatorColor: _primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.grey,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primary);
          }
          return const IconThemeData(color: Colors.grey);
        }),
        elevation: 8,
        height: 80,
      ),
    );
  }
}
