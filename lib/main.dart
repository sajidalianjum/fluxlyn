import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'src/app.dart';
import 'src/core/services/storage_service.dart';
import 'src/core/services/error_handler.dart';
import 'src/core/presentation/pages/splash_page.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/models/settings_model.dart';

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
  ThemeMode? _initialTheme;

  @override
  void initState() {
    super.initState();
    _loadInitialTheme();
  }

  Future<void> _loadInitialTheme() async {
    try {
      await Hive.initFlutter();
      final settingsBox = await Hive.openBox('settings');
      final settingsJson = settingsBox.get('settings');
      if (settingsJson != null) {
        final decoded = jsonDecode(settingsJson as String) as Map<String, dynamic>;
        final themeModeStr = decoded['themeMode'] as String?;
        final themeMode = themeModeStr != null 
            ? AppThemeMode.fromString(themeModeStr).toThemeMode()
            : ThemeMode.system;
        setState(() => _initialTheme = themeMode);
        return;
      }
    } catch (_) {}
    setState(() => _initialTheme = ThemeMode.system);
  }

  void _onStorageReady() {
    setState(() => _isReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return MyApp(storageService: _storageService);
    }

    final themeMode = _initialTheme ?? ThemeMode.system;

    return MaterialApp(
      title: 'Fluxlyn',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: SplashPage(
        storageService: _storageService,
        onReady: _onStorageReady,
      ),
    );
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
