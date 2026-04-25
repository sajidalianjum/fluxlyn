import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/host_key_verification_helper.dart';
import 'features/connections/presentation/pages/connections_page.dart';
import 'features/connections/providers/connections_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'core/services/storage_service.dart';

class MyApp extends StatelessWidget {
  final StorageService storageService;

  const MyApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storageService),
        ChangeNotifierProvider(
          create: (_) => ConnectionsProvider(storageService),
        ),
        ChangeNotifierProvider(create: (_) => DashboardProvider(storageService)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(storageService)),
      ],
      child: MaterialApp(
        navigatorKey: HostKeyVerificationHelper.navigatorKey,
        title: 'Fluxlyn',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const ConnectionsPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
