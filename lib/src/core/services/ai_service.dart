import 'dart:convert';
import 'dart:async' as async;
import 'package:http/http.dart' as http;
import '../models/settings_model.dart';
import '../models/exceptions.dart';

class AIService {
  static const Duration _requestTimeout = Duration(seconds: 30);

  Future<String> generateSQL({
    required String prompt,
    required String schema,
    required AppSettings settings,
  }) async {
    if (settings.apiKey.isEmpty) {
      throw ValidationException(
        'API Key is not set in settings',
        field: 'apiKey',
      );
    }

    final endpoint = settings.endpoint.isNotEmpty
        ? settings.endpoint
        : settings.provider.defaultEndpoint;

    final systemPrompt =
        """
You are an expert SQL generator for MySQL.
Given the following database schema, generate a single SQL query that fulfills the user's request.
ONLY return the SQL query, no explanations, no markdown code blocks, just the raw SQL.

SCHEMA:
$schema
""";

    final body = {
      'model': settings.modelName.isNotEmpty
          ? settings.modelName
          : _getModelForProvider(settings.provider),
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.0,
    };

    http.Response response;

    try {
      response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${settings.apiKey}',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on async.TimeoutException {
      throw TimeoutException(
        'AI API request timed out after ${_requestTimeout.inSeconds} seconds',
        timeout: _requestTimeout,
        operation: 'generateSQL',
      );
    } catch (e) {
      throw NetworkException(
        'Failed to connect to AI API',
        url: endpoint,
        originalError: e,
      );
    }

    if (response.statusCode != 200) {
      String errorMessage = 'AI API Error: ${response.statusCode}';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('error')) {
          final errorDetail = errorData['error'];
          if (errorDetail is Map && errorDetail.containsKey('message')) {
            errorMessage = errorDetail['message'];
          } else if (errorDetail is String) {
            errorMessage = errorDetail;
          }
        }
      } catch (_) {
        errorMessage =
            '${response.statusCode}: ${response.body.substring(0, 200)}';
      }

      throw NetworkException(
        errorMessage,
        url: endpoint,
        statusCode: response.statusCode,
        originalError: response.body,
      );
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw NetworkException(
        'Failed to parse AI response: Invalid JSON',
        url: endpoint,
        originalError: e,
      );
    }

    String sql = '';

    try {
      if (settings.provider == AIProvider.anthropic) {
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final contentItem = content[0] as Map?;
          sql = (contentItem?['text'] as String?) ?? '';
        }
      } else {
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices[0] as Map?;
          final message = choice?['message'] as Map?;
          sql = (message?['content'] as String?) ?? '';
        }
      }
    } catch (e) {
      throw NetworkException(
        'Failed to extract SQL from AI response',
        url: endpoint,
        originalError: e,
      );
    }

    if (sql.isEmpty) {
      throw NetworkException('AI returned empty SQL query', url: endpoint);
    }

    sql = sql.replaceAll('```sql', '').replaceAll('```', '').trim();

    if (sql.isEmpty) {
      throw NetworkException('AI returned invalid SQL query', url: endpoint);
    }

    return sql;
  }

  String _getModelForProvider(AIProvider provider) {
    switch (provider) {
      case AIProvider.openai:
        return 'gpt-4o';
      case AIProvider.anthropic:
        return 'claude-3-5-sonnet-20240620';
      case AIProvider.groq:
        return 'llama-3.1-70b-versatile';
      case AIProvider.xai:
        return 'grok-beta';
      case AIProvider.openrouter:
        return 'openai/gpt-4o';
      case AIProvider.custom:
        return 'custom-model';
    }
  }
}
