import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluxlyn/src/features/connections/presentation/pages/connections_page.dart';
import 'package:fluxlyn/src/features/connections/providers/connections_provider.dart';
import 'package:fluxlyn/src/features/settings/providers/settings_provider.dart';
import 'package:fluxlyn/src/core/services/storage_service.dart';
import 'package:fluxlyn/src/core/models/settings_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Persistence Integration Tests', () {
    late StorageService storageService;

    setUpAll(() async {
      storageService = StorageService();
      await storageService.init();
    });

    testWidgets('settings persistence and retrieval', (tester) async {
      final customSettings = AppSettings(
        themeMode: AppThemeMode.dark,
        lock: false,
        readOnlyMode: true,
        provider: AIProvider.anthropic,
        apiKey: 'test-api-key-123',
        endpoint: 'https://api.anthropic.com/v1/messages',
        modelName: 'claude-3',
        masterPasswordEnabled: false,
        hasShownPasswordPrompt: false,
      );

      await storageService.saveSettings(customSettings);

      final loadedSettings = storageService.loadSettings();

      expect(loadedSettings.themeMode, AppThemeMode.dark);
      expect(loadedSettings.lock, false);
      expect(loadedSettings.readOnlyMode, true);
      expect(loadedSettings.provider, AIProvider.anthropic);
      expect(loadedSettings.apiKey, 'test-api-key-123');
      expect(loadedSettings.modelName, 'claude-3');
    });

    testWidgets('settings update through provider', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider.value(value: storageService),
              ChangeNotifierProvider(
                create: (_) => ConnectionsProvider(storageService),
              ),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(storageService),
              ),
            ],
            child: const ConnectionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final settingsProvider = SettingsProvider(storageService);

      await settingsProvider.updateSettings(
        lock: false,
        readOnlyMode: false,
        provider: AIProvider.groq,
        apiKey: 'updated-key',
      );

      expect(settingsProvider.settings.lock, false);
      expect(settingsProvider.settings.readOnlyMode, false);
      expect(settingsProvider.settings.provider, AIProvider.groq);
      expect(settingsProvider.settings.apiKey, 'updated-key');

      final persistedSettings = storageService.loadSettings();
      expect(persistedSettings.provider, AIProvider.groq);
    });

    testWidgets('settings defaults when no saved settings', (tester) async {
      final defaultSettings = AppSettings.defaultSettings();

      expect(defaultSettings.lock, true);
      expect(defaultSettings.readOnlyMode, true);
      expect(defaultSettings.provider, AIProvider.openai);
      expect(defaultSettings.apiKey, '');
      expect(defaultSettings.endpoint, AIProvider.openai.defaultEndpoint);
    });

    testWidgets('settings screen displays current values', (tester) async {
      await storageService.saveSettings(AppSettings(
        themeMode: AppThemeMode.system,
        lock: true,
        readOnlyMode: false,
        provider: AIProvider.openai,
        apiKey: 'display-test-key',
        endpoint: 'https://api.openai.com/v1/chat/completions',
        modelName: 'gpt-4',
        masterPasswordEnabled: false,
        hasShownPasswordPrompt: false,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider.value(value: storageService),
              ChangeNotifierProvider(
                create: (_) => ConnectionsProvider(storageService),
              ),
              ChangeNotifierProvider(
                create: (_) => SettingsProvider(storageService),
              ),
            ],
            child: const ConnectionsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('AI Configuration'), findsOneWidget);
    });

    testWidgets('provider change updates endpoint', (tester) async {
      final settingsProvider = SettingsProvider(storageService);

      await settingsProvider.updateSettings(
        provider: AIProvider.anthropic,
      );

      expect(
        settingsProvider.settings.endpoint,
        AIProvider.anthropic.defaultEndpoint,
      );

      await settingsProvider.updateSettings(
        provider: AIProvider.groq,
      );

      expect(
        settingsProvider.settings.endpoint,
        AIProvider.groq.defaultEndpoint,
      );
    });

    testWidgets('custom endpoint persists', (tester) async {
      final customEndpoint = 'https://custom.api.endpoint/v1/chat';

      await storageService.saveSettings(AppSettings(
        themeMode: AppThemeMode.system,
        lock: true,
        readOnlyMode: false,
        provider: AIProvider.custom,
        apiKey: 'custom-key',
        endpoint: customEndpoint,
        modelName: 'custom-model',
        masterPasswordEnabled: false,
        hasShownPasswordPrompt: false,
      ));

      final loaded = storageService.loadSettings();

      expect(loaded.endpoint, customEndpoint);
      expect(loaded.provider, AIProvider.custom);
    });
  });
}