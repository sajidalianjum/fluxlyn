import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/core/services/storage_service.dart';
import 'src/core/services/error_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _setupErrorHandlers();

  try {
    final storageService = StorageService();
    await storageService.init();
    runApp(MyApp(storageService: storageService));
  } catch (error, stackTrace) {
    ErrorHandlerService.instance.logCritical(
      error,
      stackTrace,
      'App Initialization',
      'main.dart:15',
    );
    rethrow;
  }
}

void _setupErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    ErrorHandlerService.instance.handleFlutterError(details);
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    ErrorHandlerService.instance.handleAsyncError(error, stackTrace);
    return true;
  };
}
