import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/connections/presentation/pages/connections_page.dart';
import 'src/features/connections/providers/connections_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionsProvider()),
      ],
      child: MaterialApp(
        title: 'Fluxlyn',
        theme: AppTheme.lightTheme, // Keep light explicitly if needed, but we focus on dark
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Force dark for this task
        home: const ConnectionsPage(),
      ),
    );
  }
}
