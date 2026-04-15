import '../services/error_handler.dart';

class ErrorReporter {
  static final ErrorHandlerService _handler = ErrorHandlerService.instance;

  static void error(
    dynamic error,
    StackTrace? stackTrace,
    String context,
    String fileLocation,
  ) {
    _handler.logError(error, stackTrace, context, fileLocation);
  }

  static void warning(
    dynamic message,
    StackTrace? stackTrace,
    String context,
    String fileLocation,
  ) {
    _handler.logWarning(message, stackTrace, context, fileLocation);
  }

  static void info(dynamic message, String context, String fileLocation) {
    _handler.logInfo(message, context, fileLocation);
  }

  static void debug(dynamic message, String context, String fileLocation) {
    _handler.logDebug(message, context, fileLocation);
  }

  static void critical(
    dynamic error,
    StackTrace? stackTrace,
    String context,
    String fileLocation,
  ) {
    _handler.logCritical(error, stackTrace, context, fileLocation);
  }
}
