import 'package:flutter/material.dart';

enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromString(String value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  String get displayName {
    switch (this) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

enum AIProvider {
  openai,
  anthropic,
  openrouter,
  groq,
  xai,
  custom;

  static AIProvider fromString(String value) {
    return AIProvider.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AIProvider.openai,
    );
  }

  String get displayName {
    switch (this) {
      case AIProvider.openai:
        return 'OpenAI';
      case AIProvider.anthropic:
        return 'Anthropic';
      case AIProvider.openrouter:
        return 'OpenRouter';
      case AIProvider.groq:
        return 'Groq';
      case AIProvider.xai:
        return 'xAI (Grok)';
      case AIProvider.custom:
        return 'Custom';
    }
  }

  String get defaultEndpoint {
    switch (this) {
      case AIProvider.openai:
        return 'https://api.openai.com/v1/chat/completions';
      case AIProvider.anthropic:
        return 'https://api.anthropic.com/v1/messages';
      case AIProvider.openrouter:
        return 'https://openrouter.ai/api/v1/chat/completions';
      case AIProvider.groq:
        return 'https://api.groq.com/openai/v1/chat/completions';
      case AIProvider.xai:
        return 'https://api.x.ai/v1/chat/completions';
      case AIProvider.custom:
        return '';
    }
  }
}

class AppSettings {
  final AppThemeMode themeMode;
  final bool lock;
  final bool readOnlyMode;
  final AIProvider provider;
  final String apiKey;
  final String endpoint;
  final String modelName;
  final bool masterPasswordEnabled;
  final bool hasShownPasswordPrompt;

  AppSettings({
    required this.themeMode,
    required this.lock,
    required this.readOnlyMode,
    required this.provider,
    required this.apiKey,
    required this.endpoint,
    required this.modelName,
    required this.masterPasswordEnabled,
    required this.hasShownPasswordPrompt,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      themeMode: AppThemeMode.system,
      lock: true,
      readOnlyMode: true,
      provider: AIProvider.openai,
      apiKey: '',
      endpoint: AIProvider.openai.defaultEndpoint,
      modelName: '',
      masterPasswordEnabled: false,
      hasShownPasswordPrompt: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'lock': lock,
      'readOnlyMode': readOnlyMode,
      'provider': provider.name,
      'apiKey': apiKey,
      'endpoint': endpoint,
      'modelName': modelName,
      'masterPasswordEnabled': masterPasswordEnabled,
      'hasShownPasswordPrompt': hasShownPasswordPrompt,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: AppThemeMode.fromString(json['themeMode'] ?? 'system'),
      lock: json['lock'] ?? true,
      readOnlyMode: json['readOnlyMode'] ?? false,
      provider: AIProvider.fromString(json['provider'] ?? 'openai'),
      apiKey: json['apiKey'] ?? '',
      endpoint:
          json['endpoint'] ??
          AIProvider.fromString(json['provider'] ?? 'openai').defaultEndpoint,
      modelName: json['modelName'] ?? '',
      masterPasswordEnabled: json['masterPasswordEnabled'] ?? false,
      hasShownPasswordPrompt: json['hasShownPasswordPrompt'] ?? false,
    );
  }

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? lock,
    bool? readOnlyMode,
    AIProvider? provider,
    String? apiKey,
    String? endpoint,
    String? modelName,
    bool? masterPasswordEnabled,
    bool? hasShownPasswordPrompt,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      lock: lock ?? this.lock,
      readOnlyMode: readOnlyMode ?? this.readOnlyMode,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      endpoint: endpoint ?? this.endpoint,
      modelName: modelName ?? this.modelName,
      masterPasswordEnabled: masterPasswordEnabled ?? this.masterPasswordEnabled,
      hasShownPasswordPrompt: hasShownPasswordPrompt ?? this.hasShownPasswordPrompt,
    );
  }
}
