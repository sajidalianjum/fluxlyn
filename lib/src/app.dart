import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/connections/presentation/pages/connections_page.dart';
import 'features/connections/providers/connections_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'core/services/storage_service.dart';

class MyApp extends StatelessWidget {
  final StorageService storageService;

  const MyApp({super.key, required this.storageService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionsProvider(storageService)),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: MaterialApp(
        title: 'Fluxlyn',
        theme: AppTheme.lightTheme, // Fallback
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Enforce Dark Mode
        home: const ConnectionsPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
