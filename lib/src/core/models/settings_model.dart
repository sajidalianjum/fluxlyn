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
  final bool lockDelete;
  final bool lockDrop;
  final AIProvider provider;
  final String apiKey;
  final String endpoint;
  final String modelName;

  AppSettings({
    required this.lockDelete,
    required this.lockDrop,
    required this.provider,
    required this.apiKey,
    required this.endpoint,
    required this.modelName,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      lockDelete: true,
      lockDrop: true,
      provider: AIProvider.openai,
      apiKey: '',
      endpoint: AIProvider.openai.defaultEndpoint,
      modelName: '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lockDelete': lockDelete,
      'lockDrop': lockDrop,
      'provider': provider.name,
      'apiKey': apiKey,
      'endpoint': endpoint,
      'modelName': modelName,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      lockDelete: json['lockDelete'] ?? true,
      lockDrop: json['lockDrop'] ?? true,
      provider: AIProvider.fromString(json['provider'] ?? 'openai'),
      apiKey: json['apiKey'] ?? '',
      endpoint:
          json['endpoint'] ??
          AIProvider.fromString(json['provider'] ?? 'openai').defaultEndpoint,
      modelName: json['modelName'] ?? '',
    );
  }

  AppSettings copyWith({
    bool? lockDelete,
    bool? lockDrop,
    AIProvider? provider,
    String? apiKey,
    String? endpoint,
    String? modelName,
  }) {
    return AppSettings(
      lockDelete: lockDelete ?? this.lockDelete,
      lockDrop: lockDrop ?? this.lockDrop,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      endpoint: endpoint ?? this.endpoint,
      modelName: modelName ?? this.modelName,
    );
  }
}
