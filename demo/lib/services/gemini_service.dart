import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const String _apiKeyPref = 'gemini_api_key';
  GenerativeModel? _model;
  String? _apiKey;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_apiKeyPref);
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      _initModel(_apiKey!);
    }
  }

  void _initModel(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
      ),
    );
  }

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;
  String? get apiKey => _apiKey;

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await prefs.remove(_apiKeyPref);
      _apiKey = null;
      _model = null;
    } else {
      await prefs.setString(_apiKeyPref, key);
      _apiKey = key;
      _initModel(key);
    }
  }

  Future<String> generateFormContract(String prompt) async {
    if (_model == null) {
      throw Exception('API key not configured');
    }

    const systemPrompt = '''
You are GenUIForm, an AI that generates adaptive form specifications.
Based on the user's request, create a form specification with:
1. Form name and description
2. Field specifications (type, label, validation, input style)
3. Adaptive rules based on user engagement levels
4. Outcome paths

Return a structured response describing the form configuration.
Focus on creating forms that adapt to user engagement:
- High engagement: Show all fields, detailed options
- Medium engagement: Show important fields, streamlined flow
- Low engagement: Show only critical required fields

Suggest form postures: reassuring, confident, or casual based on context.
''';

    final content = [
      Content.text('$systemPrompt\n\nUser request: $prompt'),
    ];

    try {
      final response = await _model!.generateContent(content);
      return response.text ?? 'Unable to generate form specification';
    } catch (e) {
      throw Exception('Failed to generate: $e');
    }
  }

  Stream<String> generateFormContractStream(String prompt) async* {
    if (_model == null) {
      throw Exception('API key not configured');
    }

    const systemPrompt = '''
You are GenUIForm, an AI that generates adaptive form specifications.
Based on the user's request, create a form specification with:
1. Form name and description
2. Field specifications (type, label, validation, input style)
3. Adaptive rules based on user engagement levels
4. Outcome paths

Return a structured response describing the form configuration.
Focus on creating forms that adapt to user engagement:
- High engagement: Show all fields, detailed options
- Medium engagement: Show important fields, streamlined flow
- Low engagement: Show only critical required fields

Suggest form postures: reassuring, confident, or casual based on context.
''';

    final content = [
      Content.text('$systemPrompt\n\nUser request: $prompt'),
    ];

    try {
      final response = _model!.generateContentStream(content);
      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      throw Exception('Failed to generate: $e');
    }
  }
}