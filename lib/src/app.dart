import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/welcome/presentation/welcome_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluxlyn',
      theme: AppTheme.lightTheme,
      home: const WelcomePage(),
    );
  }
}
