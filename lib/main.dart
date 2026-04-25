import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/core/services/storage_service.dart';
import 'src/core/services/error_handler.dart';
import 'src/core/presentation/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _setupErrorHandlers();

  runApp(const FluxlynApp());
}

class FluxlynApp extends StatefulWidget {
  const FluxlynApp({super.key});

  @override
  State<FluxlynApp> createState() => _FluxlynAppState();
}

class _FluxlynAppState extends State<FluxlynApp> {
  final StorageService _storageService = StorageService();
  bool _isReady = false;

  void _onStorageReady() {
    setState(() => _isReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return MaterialApp(
        title: 'Fluxlyn',
        theme: ThemeData.dark(),
        debugShowCheckedModeBanner: false,
        home: SplashPage(
          storageService: _storageService,
          onReady: _onStorageReady,
        ),
      );
    }

    return MyApp(storageService: _storageService);
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
