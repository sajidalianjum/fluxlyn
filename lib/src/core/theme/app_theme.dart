import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static const Color _primary = AppConstants.colorPrimary;
  static const Color _backgroundDark = AppConstants.colorBackgroundDark;
  static const Color _cardBackgroundDark = AppConstants.colorCardBackgroundDark;
  static const Color _textPrimaryDark = AppConstants.colorTextPrimaryDark;
  static const Color _backgroundLight = AppConstants.colorBackgroundLight;
  static const Color _cardBackgroundLight = AppConstants.colorCardBackgroundLight;
  static const Color _textPrimaryLight = AppConstants.colorTextPrimaryLight;
  static const Color _borderLight = AppConstants.colorBorderLight;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        brightness: Brightness.light,
        surface: _cardBackgroundLight,
      ).copyWith(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDBEAFE),
        onPrimaryContainer: const Color(0xFF1E40AF),
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: _textPrimaryLight, displayColor: _textPrimaryLight),
      cardTheme: const CardThemeData(
        color: _cardBackgroundLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: _borderLight),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _textPrimaryLight,
        ),
        iconTheme: IconThemeData(color: _primary),
      ),
      iconTheme: const IconThemeData(color: _primary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _backgroundLight,
        indicatorColor: _primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textPrimaryLight,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primary);
          }
          return IconThemeData(color: Colors.grey.shade600);
        }),
        elevation: 8,
        height: 80,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _backgroundLight,
        indicatorColor: _primary.withValues(alpha: 0.2),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _textPrimaryLight,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.grey.shade600,
        ),
        selectedIconTheme: const IconThemeData(color: _primary),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade400;
          }
          if (states.contains(WidgetState.selected)) {
            return _primary;
          }
          return Colors.grey.shade50;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade300;
          }
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.5);
          }
          return Colors.grey.shade300;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade400;
          }
          return Colors.transparent;
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _cardBackgroundLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _borderLight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardBackgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _backgroundDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        brightness: Brightness.dark,
        surface: _cardBackgroundDark,
      ).copyWith(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF1E40AF),
        onPrimaryContainer: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: _textPrimaryDark, displayColor: _textPrimaryDark),
      cardTheme: const CardThemeData(
        color: _cardBackgroundDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _backgroundDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _textPrimaryDark,
        ),
        iconTheme: IconThemeData(color: _primary),
      ),
      iconTheme: const IconThemeData(color: _primary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _backgroundDark,
        indicatorColor: _primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _textPrimaryDark,
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
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _backgroundDark,
        indicatorColor: _primary.withValues(alpha: 0.2),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _textPrimaryDark,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.grey[600],
        ),
        selectedIconTheme: const IconThemeData(color: _primary),
        unselectedIconTheme: IconThemeData(color: Colors.grey[600]),
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade600;
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade800;
          }
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.6);
          }
          return Colors.grey.shade700;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade600;
          }
          return Colors.transparent;
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _cardBackgroundDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x0DFFFFFF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardBackgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x0DFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0x0DFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }
}
