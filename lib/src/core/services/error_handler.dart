import 'dart:io';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error, critical }

class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  static ErrorHandlerService get instance => _instance;
  ErrorHandlerService._internal();

  static const String _separator =
      '═══════════════════════════════════════════════════';
  static const int _maxStackTraceLines = 15;

  void logError(
    dynamic error,
    StackTrace? stackTrace,
    String context,
    String fileLocation,
  ) {
    _log(LogLevel.error, error, stackTrace, context, fileLocation);
  }

  void logWarning(
    dynamic message,
    StackTrace? stackTrace,
    String context,
    String fileLocation,
  ) {
    _log(LogLevel.warning, message, stackTrace, context, fileLocation);
  }

  void logInfo(dynamic message, String context, String fileLocation) {
    _log(LogLevel.info, message, null, context, fileLocation);
  }

  void logDebug(dynamic message, String context, String fileLocation) {
    _log(LogLevel.debug, message, null, context, fileLocation);
  }

  void logCritical(
    dynamic error,
    StackTrace? stackTrace,
    String context,
    String fileLocation,
  ) {
    _log(LogLevel.critical, error, stackTrace, context, fileLocation);
  }

  void _log(
    LogLevel level,
    dynamic message,
    StackTrace? stackTrace,
    String context,
    String fileLocation,
  ) {
    if (level == LogLevel.info || level == LogLevel.debug) {
      return;
    }

    final timestamp = DateTime.now().toString();
    final emoji = _getEmoji(level);
    final levelName = _getLevelName(level);

    stdout.writeln(_separator);
    stdout.writeln('$emoji $levelName - $timestamp');
    stdout.writeln(_separator);
    stdout.writeln('');

    stdout.writeln('📌 Type: ${message.runtimeType}');
    stdout.writeln('💬 Message: $message');
    stdout.writeln('📍 Context: $context');
    stdout.writeln('📁 File: $fileLocation');
    stdout.writeln('');

    if (stackTrace != null) {
      stdout.writeln('📝 Stack Trace:');
      final formattedTrace = _formatStackTrace(stackTrace);
      stdout.writeln(formattedTrace);
      stdout.writeln('');
    }

    stdout.writeln(_separator);
    stdout.writeln('');
  }

  String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '🚨';
      case LogLevel.critical:
        return '🔥';
    }
  }

  String _getLevelName(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.critical:
        return 'CRITICAL';
    }
  }

  String _formatStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    final relevantLines = lines.take(_maxStackTraceLines).toList();

    final formatted = StringBuffer();
    for (var i = 0; i < relevantLines.length; i++) {
      final line = relevantLines[i].trim();
      if (line.isNotEmpty) {
        formatted.writeln('  $line');
      }
    }

    if (lines.length > _maxStackTraceLines) {
      formatted.writeln(
        '  ... (${lines.length - _maxStackTraceLines} more frames)',
      );
    }

    return formatted.toString();
  }

  void handleFlutterError(FlutterErrorDetails details) {
    logError(
      details.exception,
      details.stack,
      'Flutter Framework Error',
      details.library ?? 'Unknown',
    );
  }

  void handleAsyncError(Object error, StackTrace stackTrace) {
    logCritical(error, stackTrace, 'Uncaught Async Error', 'Global Handler');
  }
}
