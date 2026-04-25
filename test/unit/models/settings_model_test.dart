import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/core/models/settings_model.dart';

void main() {
  group('AIProvider', () {
    group('fromString', () {
      test('returns correct provider for valid string', () {
        expect(AIProvider.fromString('openai'), AIProvider.openai);
        expect(AIProvider.fromString('anthropic'), AIProvider.anthropic);
        expect(AIProvider.fromString('openrouter'), AIProvider.openrouter);
        expect(AIProvider.fromString('groq'), AIProvider.groq);
        expect(AIProvider.fromString('xai'), AIProvider.xai);
        expect(AIProvider.fromString('custom'), AIProvider.custom);
      });

      test('returns openai for invalid string', () {
        expect(AIProvider.fromString('invalid'), AIProvider.openai);
        expect(AIProvider.fromString(''), AIProvider.openai);
        expect(AIProvider.fromString('unknown'), AIProvider.openai);
      });
    });

    group('displayName', () {
      test('returns correct display names', () {
        expect(AIProvider.openai.displayName, 'OpenAI');
        expect(AIProvider.anthropic.displayName, 'Anthropic');
        expect(AIProvider.openrouter.displayName, 'OpenRouter');
        expect(AIProvider.groq.displayName, 'Groq');
        expect(AIProvider.xai.displayName, 'xAI (Grok)');
        expect(AIProvider.custom.displayName, 'Custom');
      });
    });

    group('defaultEndpoint', () {
      test('returns correct endpoints for each provider', () {
        expect(
          AIProvider.openai.defaultEndpoint,
          'https://api.openai.com/v1/chat/completions',
        );
        expect(
          AIProvider.anthropic.defaultEndpoint,
          'https://api.anthropic.com/v1/messages',
        );
        expect(
          AIProvider.openrouter.defaultEndpoint,
          'https://openrouter.ai/api/v1/chat/completions',
        );
        expect(
          AIProvider.groq.defaultEndpoint,
          'https://api.groq.com/openai/v1/chat/completions',
        );
        expect(
          AIProvider.xai.defaultEndpoint,
          'https://api.x.ai/v1/chat/completions',
        );
        expect(AIProvider.custom.defaultEndpoint, '');
      });
    });
  });

  group('AppSettings', () {
    group('defaultSettings', () {
      test('creates settings with correct default values', () {
        final settings = AppSettings.defaultSettings();

        expect(settings.themeMode, AppThemeMode.system);
        expect(settings.lock, true);
        expect(settings.readOnlyMode, true);
        expect(settings.provider, AIProvider.openai);
        expect(settings.apiKey, '');
        expect(settings.endpoint, AIProvider.openai.defaultEndpoint);
        expect(settings.modelName, '');
        expect(settings.masterPasswordEnabled, false);
        expect(settings.hasShownPasswordPrompt, false);
      });
    });

    group('toJson', () {
      test('serializes settings to JSON correctly', () {
        final settings = AppSettings(
          themeMode: AppThemeMode.dark,
          lock: true,
          readOnlyMode: false,
          provider: AIProvider.anthropic,
          apiKey: 'test-api-key',
          endpoint: 'https://custom.endpoint',
          modelName: 'gpt-4',
          masterPasswordEnabled: false,
          hasShownPasswordPrompt: false,
        );

        final json = settings.toJson();

        expect(json['themeMode'], 'dark');
        expect(json['lock'], true);
        expect(json['readOnlyMode'], false);
        expect(json['provider'], 'anthropic');
        expect(json['apiKey'], 'test-api-key');
        expect(json['endpoint'], 'https://custom.endpoint');
        expect(json['modelName'], 'gpt-4');
        expect(json['masterPasswordEnabled'], false);
        expect(json['hasShownPasswordPrompt'], false);
      });

      test('serializes default settings correctly', () {
        final settings = AppSettings.defaultSettings();
        final json = settings.toJson();

        expect(json['lock'], true);
        expect(json['readOnlyMode'], true);
        expect(json['provider'], 'openai');
        expect(json['apiKey'], '');
        expect(json['modelName'], '');
      });
    });

    group('fromJson', () {
      test('deserializes JSON to settings correctly', () {
        final json = {
          'lock': false,
          'readOnlyMode': true,
          'provider': 'anthropic',
          'apiKey': 'sk-test',
          'endpoint': 'https://api.anthropic.com/v1/messages',
          'modelName': 'claude-3',
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.lock, false);
        expect(settings.readOnlyMode, true);
        expect(settings.provider, AIProvider.anthropic);
        expect(settings.apiKey, 'sk-test');
        expect(settings.endpoint, 'https://api.anthropic.com/v1/messages');
        expect(settings.modelName, 'claude-3');
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};

        final settings = AppSettings.fromJson(json);

        expect(settings.lock, true);
        expect(settings.readOnlyMode, false);
        expect(settings.provider, AIProvider.openai);
        expect(settings.apiKey, '');
        expect(settings.endpoint, AIProvider.openai.defaultEndpoint);
        expect(settings.modelName, '');
      });

      test('handles partial JSON correctly', () {
        final json = {
          'lock': false,
          'provider': 'groq',
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.lock, false);
        expect(settings.provider, AIProvider.groq);
        expect(settings.readOnlyMode, false);
        expect(settings.apiKey, '');
        expect(settings.endpoint, AIProvider.groq.defaultEndpoint);
      });

      test('uses default endpoint when provider specified but endpoint missing', () {
        final json = {
          'provider': 'xai',
        };

        final settings = AppSettings.fromJson(json);

        expect(settings.provider, AIProvider.xai);
        expect(settings.endpoint, AIProvider.xai.defaultEndpoint);
      });
    });

    group('copyWith', () {
      test('copies with new lock value', () {
        final original = AppSettings.defaultSettings();
        final copied = original.copyWith(lock: false);

        expect(copied.lock, false);
        expect(copied.readOnlyMode, original.readOnlyMode);
        expect(copied.provider, original.provider);
        expect(copied.apiKey, original.apiKey);
        expect(copied.endpoint, original.endpoint);
        expect(copied.modelName, original.modelName);
      });

      test('copies with new provider', () {
        final original = AppSettings.defaultSettings();
        final copied = original.copyWith(provider: AIProvider.anthropic);

        expect(copied.provider, AIProvider.anthropic);
        expect(copied.lock, original.lock);
      });

      test('copies with multiple new values', () {
        final original = AppSettings.defaultSettings();
        final copied = original.copyWith(
          lock: false,
          readOnlyMode: true,
          provider: AIProvider.custom,
          apiKey: 'new-key',
          endpoint: 'https://new.endpoint',
          modelName: 'new-model',
        );

        expect(copied.lock, false);
        expect(copied.readOnlyMode, true);
        expect(copied.provider, AIProvider.custom);
        expect(copied.apiKey, 'new-key');
        expect(copied.endpoint, 'https://new.endpoint');
        expect(copied.modelName, 'new-model');
      });

      test('returns identical settings when no values provided', () {
        final original = AppSettings(
          themeMode: AppThemeMode.dark,
          lock: true,
          readOnlyMode: false,
          provider: AIProvider.groq,
          apiKey: 'key',
          endpoint: 'endpoint',
          modelName: 'model',
          masterPasswordEnabled: true,
          hasShownPasswordPrompt: true,
        );
        final copied = original.copyWith();

        expect(copied.themeMode, original.themeMode);
        expect(copied.lock, original.lock);
        expect(copied.readOnlyMode, original.readOnlyMode);
        expect(copied.provider, original.provider);
        expect(copied.apiKey, original.apiKey);
        expect(copied.endpoint, original.endpoint);
        expect(copied.modelName, original.modelName);
        expect(copied.masterPasswordEnabled, original.masterPasswordEnabled);
        expect(copied.hasShownPasswordPrompt, original.hasShownPasswordPrompt);
      });
    });
  });
}