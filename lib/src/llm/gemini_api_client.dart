// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'llm_client.dart';
import '../models/message.dart';

/// A [LlmClient] that calls the public Google AI Studio Gemini REST endpoint
/// (`generativelanguage.googleapis.com`) using a static API key.
///
/// Use this when you have a free-tier Gemini API key from
/// [Google AI Studio](https://aistudio.google.com/apikey) and don't want to
/// set up Vertex AI / GCP. The request and response shapes are identical to
/// Vertex's `:streamGenerateContent` endpoint, so swapping transports is just
/// a matter of credential plumbing.
///
/// **Never ship in a mobile app.** Bundles the API key client-side; for demos
/// and server-side usage only.
///
/// Auth is sent as `x-goog-api-key: <apiKey>`. Static `AIza...`-prefixed keys
/// are accepted; OAuth tokens are not.
///
/// Example:
/// ```dart
/// final client = GeminiApiClient(apiKey: 'AIza...');
/// final stream = client.generate(
///   systemPrompt: systemPrompt,
///   messages: session.history.map((a) => a.message).toList(),
///   responseSchema: generativeStrategyResponseSchema(),
///   model: 'gemini-2.5-flash',
/// );
/// final json = await stream.first;
/// ```
class GeminiApiClient extends LlmClient {
  /// The Gemini API key (typically `AIza...`-prefixed).
  final String apiKey;

  final http.Client _httpClient;

  /// Creates a [GeminiApiClient].
  ///
  /// Inject [httpClient] to use a test double (e.g. `MockClient` from
  /// `package:http/testing.dart`). If omitted, a real [http.Client] is used.
  GeminiApiClient({
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Uri _buildUri(String model) {
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model'
      ':streamGenerateContent',
    );
  }

  Map<String, dynamic> _messageToContent(Message message) {
    final role = switch (message.role) {
      MessageRole.user => 'user',
      MessageRole.assistant => 'model',
      MessageRole.system => 'user',
    };
    return {
      'role': role,
      'parts': [
        {'text': message.content},
      ],
    };
  }

  Duration? _parseRetryAfter(http.Response response) {
    final raw = response.headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw);
    if (seconds == null) return null;
    return Duration(seconds: seconds);
  }

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    double temperature = 0.7,
  }) {
    return _generateAsync(
      systemPrompt: systemPrompt,
      messages: messages,
      responseSchema: responseSchema,
      model: model,
      temperature: temperature,
    );
  }

  Stream<String> _generateAsync({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    required double temperature,
  }) async* {
    final uri = _buildUri(model);

    // Gemini AI Studio's :streamGenerateContent rejects empty `contents` with
    // HTTP 400. When the caller has only a system prompt to send, synthesize
    // a single user turn so the request is well-formed.
    final effectiveMessages = messages.isEmpty
        ? [const Message(role: MessageRole.user, content: 'Begin.')]
        : messages;

    final payload = {
      'contents': effectiveMessages.map(_messageToContent).toList(),
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'generationConfig': {
        'temperature': temperature,
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
      },
    };

    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } on SocketException catch (e) {
      throw NetworkError('Socket error: ${e.message}', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkError('HTTP client error: ${e.message}', cause: e);
    } on TimeoutException catch (e) {
      throw NetworkError('Request timed out', cause: e);
    } catch (e) {
      throw UnknownError('Unexpected error during HTTP request', cause: e);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthError(
        'Gemini API returned HTTP ${response.statusCode}: ${response.body}',
      );
    }

    if (response.statusCode == 429) {
      throw RateLimitError(
        'Gemini API rate limit exceeded (HTTP 429)',
        retryAfter: _parseRetryAfter(response),
      );
    }

    if (response.statusCode >= 500) {
      throw NetworkError(
        'Gemini API server error (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    if (response.statusCode >= 400) {
      throw SchemaError(
        'Gemini API rejected request (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    List<dynamic> chunks;
    try {
      chunks = jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      throw SchemaError(
        'Failed to parse Gemini API response envelope as JSON array: $e',
      );
    }

    final buffer = StringBuffer();
    for (final chunk in chunks) {
      try {
        final chunkMap = chunk as Map<String, dynamic>;
        final candidates = chunkMap['candidates'] as List<dynamic>;
        for (final candidate in candidates) {
          final content =
              (candidate as Map<String, dynamic>)['content'] as Map<String, dynamic>;
          final parts = content['parts'] as List<dynamic>;
          for (final part in parts) {
            final text = (part as Map<String, dynamic>)['text'] as String;
            buffer.write(text);
          }
        }
      } catch (e) {
        throw SchemaError(
          'Failed to extract text from Gemini API response chunk: $e',
        );
      }
    }

    final accumulated = buffer.toString();

    try {
      jsonDecode(accumulated);
    } catch (e) {
      throw SchemaError(
        'Gemini API response text is not valid JSON: $e\n'
        'Raw text (first 500 chars): ${accumulated.substring(0, accumulated.length.clamp(0, 500))}',
      );
    }

    yield accumulated;
  }
}
