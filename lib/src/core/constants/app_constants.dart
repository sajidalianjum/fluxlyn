import 'package:flutter/material.dart';

/// Application-wide constants for Fluxlyn
/// Centralizes all magic numbers and hard-coded values for better maintainability
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // ========== Database Port Constants ==========
  /// Default MySQL port
  static const int portMySQL = 3306;

  /// Default PostgreSQL port
  static const int portPostgreSQL = 5432;

  /// Default SSH port
  static const int portSSH = 22;

  // ========== Color Constants ==========
  /// Primary blue color (#3B82F6)
  static const Color colorPrimary = Color(0xFF3B82F6);

  /// Background dark color (#0F172A)
  static const Color colorBackgroundDark = Color(0xFF0F172A);

  /// Card background color dark (#1E293B)
  static const Color colorCardBackgroundDark = Color(0xFF1E293B);

  /// Elevated surface color dark - for panels/cards that need more emphasis (#243447)
  static const Color colorSurfaceElevatedDark = Color(0xFF243447);

  /// Border color dark - subtle borders for depth (#334155 with opacity)
  static const Color colorBorderDark = Color(0x1AFFFFFF); // 10% white

  /// Border color dark stronger - for interactive elements (#334155)
  static const Color colorBorderDarkStrong = Color(0xFF334155);

  /// Background light color (#F8FAFC)
  static const Color colorBackgroundLight = Color(0xFFF8FAFC);

  /// Card background color light (white)
  static const Color colorCardBackgroundLight = Colors.white;

  /// Text primary dark (white)
  static const Color colorTextPrimaryDark = Colors.white;

  /// Text primary light (#1E293B)
  static const Color colorTextPrimaryLight = Color(0xFF1E293B);

  /// Border color light (#E2E8F0)
  static const Color colorBorderLight = Color(0xFFE2E8F0);

  // Legacy aliases for backward compatibility
  static const Color colorBackground = colorBackgroundDark;
  static const Color colorCardBackground = colorCardBackgroundDark;

  // ========== Dimension/Spacing Constants ==========
  /// Extra small spacing (4px)
  static const double spacingXS = 4.0;

  /// Small spacing (8px)
  static const double spacingS = 8.0;

  /// Medium spacing (16px)
  static const double spacingM = 16.0;

  /// Large spacing (24px)
  static const double spacingL = 24.0;

  /// Extra large spacing (32px)
  static const double spacingXL = 32.0;

  /// Double extra large spacing (48px)
  static const double spacingXXL = 48.0;

  // ========== Font Size Constants ==========
  /// Small font size (12px)
  static const double fontSizeS = 12.0;

  /// Regular font size (14px)
  static const double fontSizeM = 14.0;

  /// Medium font size (16px)
  static const double fontSizeL = 16.0;

  /// Large font size (18px)
  static const double fontSizeXL = 18.0;

  /// Extra large font size (24px)
  static const double fontSizeXXL = 24.0;

  /// Display font size (48px)
  static const double displayFontSize = 48.0;

  // ========== Border Radius Constants ==========
  /// Small border radius (4px)
  static const double radiusS = 4.0;

  /// Medium border radius (8px)
  static const double radiusM = 8.0;

  /// Large border radius (12px)
  static const double radiusL = 12.0;

  // ========== Icon Size Constants ==========
  /// Small icon size (16px)
  static const double iconSizeS = 16.0;

  /// Medium icon size (24px)
  static const double iconSizeM = 24.0;

  /// Large icon size (36px)
  static const double iconSizeL = 36.0;

  /// Extra large icon size (48px)
  static const double iconSizeXL = 48.0;

  // ========== Animation Duration Constants ==========
  /// Fast animation duration (150ms)
  static const int durationFast = 150;

  /// Normal animation duration (300ms)
  static const int durationNormal = 300;

  /// Slow animation duration (500ms)
  static const int durationSlow = 500;
}
