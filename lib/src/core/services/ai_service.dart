import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/settings_model.dart';

class AIService {
  Future<String> generateSQL({
    required String prompt,
    required String schema,
    required AppSettings settings,
  }) async {
    if (settings.apiKey.isEmpty) {
      throw Exception('API Key is not set in settings');
    }

    final endpoint = settings.endpoint.isNotEmpty 
        ? settings.endpoint 
        : settings.provider.defaultEndpoint;

    final systemPrompt = """
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
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.0,
    };

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${settings.apiKey}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('AI API Error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    String sql = '';

    if (settings.provider == AIProvider.anthropic) {
      // Anthropic has a different response structure
      sql = data['content'][0]['text'];
    } else {
      // OpenAI, OpenRouter, Groq, xAI use similar structure
      sql = data['choices'][0]['message']['content'];
    }

    // Clean up SQL if it contains markdown code blocks
    sql = sql.replaceAll('```sql', '').replaceAll('```', '').trim();
    
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
