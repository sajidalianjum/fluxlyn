import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxlyn/src/features/settings/providers/settings_provider.dart';
import 'package:fluxlyn/src/core/services/storage_service.dart';
import 'package:fluxlyn/src/core/models/settings_model.dart';
import '../../helpers/mock_storage_service.dart';

void main() {
  late SettingsProvider provider;
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockStorage = MockStorageService();
    when(() => mockStorage.loadSettings())
        .thenReturn(AppSettings.defaultSettings());
    when(() => mockStorage.saveSettings(any()))
        .thenAnswer((_) async {});
    provider = SettingsProvider(mockStorage);
  });

  group('SettingsProvider', () {
    group('initialization', () {
      test('initializes with default settings', () {
        expect(provider.settings.lock, true);
        expect(provider.settings.readOnlyMode, true);
        expect(provider.settings.provider, AIProvider.openai);
        expect(provider.settings.apiKey, '');
      });

      test('loads settings from storage on creation', () {
        verify(() => mockStorage.loadSettings()).called(1);
      });

      test('sets isLoading to false after loading', () {
        expect(provider.isLoading, false);
      });

      test('sets error to null after successful load', () {
        expect(provider.error, null);
      });
    });

    group('settings getters', () {
      test('lock getter returns settings.lock', () {
        expect(provider.lock, provider.settings.lock);
      });

      test('readOnlyMode getter returns settings.readOnlyMode', () {
        expect(provider.readOnlyMode, provider.settings.readOnlyMode);
      });

      test('provider getter returns settings.provider', () {
        expect(provider.provider, provider.settings.provider);
      });

      test('apiKey getter returns settings.apiKey', () {
        expect(provider.apiKey, provider.settings.apiKey);
      });

      test('endpoint getter returns settings.endpoint', () {
        expect(provider.endpoint, provider.settings.endpoint);
      });

      test('modelName getter returns settings.modelName', () {
        expect(provider.modelName, provider.settings.modelName);
      });
    });

    group('loadSettings', () {
      test('sets isLoading to true during load', () async {
        when(() => mockStorage.loadSettings())
            .thenReturn(AppSettings.defaultSettings());

        final newProvider = SettingsProvider(mockStorage);

        expect(newProvider.isLoading, false);
      });

      test('loads custom settings from storage', () async {
        final customSettings = AppSettings(
          themeMode: AppThemeMode.dark,
          lock: false,
          readOnlyMode: true,
          provider: AIProvider.anthropic,
          apiKey: 'test-key',
          endpoint: 'https://custom.endpoint',
          modelName: 'claude-3',
          masterPasswordEnabled: false,
          hasShownPasswordPrompt: false,
        );

        when(() => mockStorage.loadSettings())
            .thenReturn(customSettings);

        final newProvider = SettingsProvider(mockStorage);

        expect(newProvider.settings.themeMode, AppThemeMode.dark);
        expect(newProvider.settings.lock, false);
        expect(newProvider.settings.provider, AIProvider.anthropic);
        expect(newProvider.settings.apiKey, 'test-key');
        expect(newProvider.settings.modelName, 'claude-3');
      });

      test('notifies listeners after loading', () async {
        when(() => mockStorage.loadSettings())
            .thenReturn(AppSettings.defaultSettings());

        final newProvider = SettingsProvider(mockStorage);

        var notified = false;
        newProvider.addListener(() => notified = true);

        await newProvider.loadSettings();

        expect(notified, true);
      });
    });

    group('updateSettings', () {
      test('updates lock setting', () async {
        await provider.updateSettings(lock: false);

        expect(provider.settings.lock, false);
        expect(provider.settings.readOnlyMode, true);
      });

      test('updates readOnlyMode setting', () async {
        await provider.updateSettings(readOnlyMode: false);

        expect(provider.settings.readOnlyMode, false);
        expect(provider.settings.lock, true);
      });

      test('updates provider setting', () async {
        await provider.updateSettings(provider: AIProvider.anthropic);

        expect(provider.settings.provider, AIProvider.anthropic);
      });

      test('updates apiKey setting', () async {
        await provider.updateSettings(apiKey: 'new-api-key');

        expect(provider.settings.apiKey, 'new-api-key');
      });

      test('updates endpoint setting', () async {
        await provider.updateSettings(endpoint: 'https://new.endpoint');

        expect(provider.settings.endpoint, 'https://new.endpoint');
      });

      test('updates modelName setting', () async {
        await provider.updateSettings(modelName: 'gpt-4-turbo');

        expect(provider.settings.modelName, 'gpt-4-turbo');
      });

      test('updates multiple settings at once', () async {
        await provider.updateSettings(
          lock: false,
          readOnlyMode: false,
          provider: AIProvider.groq,
          apiKey: 'groq-key',
          endpoint: 'https://api.groq.com/openai/v1/chat/completions',
          modelName: 'mixtral-8x7b',
        );

        expect(provider.settings.lock, false);
        expect(provider.settings.readOnlyMode, false);
        expect(provider.settings.provider, AIProvider.groq);
        expect(provider.settings.apiKey, 'groq-key');
        expect(provider.settings.endpoint, 'https://api.groq.com/openai/v1/chat/completions');
        expect(provider.settings.modelName, 'mixtral-8x7b');
      });

      test('saves updated settings to storage', () async {
        await provider.updateSettings(lock: false);

        verify(() => mockStorage.saveSettings(any())).called(1);
      });

      test('notifies listeners after update', () async {
        var notified = false;
        provider.addListener(() => notified = true);

        await provider.updateSettings(lock: false);

        expect(notified, true);
      });

      test('does not modify settings not in update', () async {
        await provider.updateSettings(lock: false);

        expect(provider.settings.readOnlyMode, true);
        expect(provider.settings.provider, AIProvider.openai);
        expect(provider.settings.apiKey, '');
      });

      test('endpoint must be explicitly updated when provider changes', () async {
        await provider.updateSettings(
          provider: AIProvider.anthropic,
          endpoint: AIProvider.anthropic.defaultEndpoint,
        );

        expect(provider.settings.endpoint, AIProvider.anthropic.defaultEndpoint);
      });
    });

    group('error handling', () {
      test('sets error when saveSettings throws', () async {
        when(() => mockStorage.saveSettings(any()))
            .thenThrow(Exception('Storage error'));

        await provider.updateSettings(lock: false);

        expect(provider.error, isNotNull);
        expect(provider.error, contains('Storage error'));
      });

      test('notifies listeners when error occurs', () async {
        when(() => mockStorage.saveSettings(any()))
            .thenThrow(Exception('Storage error'));

        var notified = false;
        provider.addListener(() => notified = true);

        await provider.updateSettings(lock: false);

        expect(notified, true);
      });

      test('clears error after successful save', () async {
        when(() => mockStorage.saveSettings(any()))
            .thenThrow(Exception('Storage error'));

        await provider.updateSettings(lock: false);

        expect(provider.error, isNotNull);

        when(() => mockStorage.saveSettings(any()))
            .thenAnswer((_) async {});

        await provider.updateSettings(lock: true);

        expect(provider.error, null);
      });
    });

    group('isLoading state', () {
      test('isLoading starts as false after initialization', () {
        expect(provider.isLoading, false);
      });

      test('isLoading becomes false after load completes', () async {
        when(() => mockStorage.loadSettings())
            .thenReturn(AppSettings.defaultSettings());

        final newProvider = SettingsProvider(mockStorage);

        await newProvider.loadSettings();

        expect(newProvider.isLoading, false);
      });
    });
  });
}