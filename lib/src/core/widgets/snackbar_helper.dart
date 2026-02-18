import 'package:flutter/material.dart';

/// Reusable utility for showing SnackBar messages across the app.
/// Extracts common patterns to reduce code duplication.
class SnackbarHelper {
  // Private constructor to prevent instantiation
  SnackbarHelper._();

  /// Shows a success message SnackBar.
  ///
  /// [context] - The build context
  /// [message] - The success message to display
  /// [duration] - How long to show the snackbar (default 3 seconds)
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows an error message SnackBar.
  ///
  /// [context] - The build context
  /// [message] - The error message to display
  /// [duration] - How long to show the snackbar (default 4 seconds for errors)
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows an info message SnackBar.
  ///
  /// [context] - The build context
  /// [message] - The info message to display
  /// [duration] - How long to show the snackbar (default 3 seconds)
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows a warning message SnackBar.
  ///
  /// [context] - The build context
  /// [message] - The warning message to display
  /// [duration] - How long to show the snackbar (default 3 seconds)
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Hides the current SnackBar if one is showing.
  ///
  /// [context] - The build context
  static void hide(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Shows a custom SnackBar with full control over appearance.
  ///
  /// [context] - The build context
  /// [snackBar] - The custom SnackBar to show
  static void showCustom(
    BuildContext context,
    SnackBar snackBar,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
