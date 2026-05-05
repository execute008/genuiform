// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'llm_client.dart';
import '../models/message.dart';

/// A [LlmClient] that calls the Vertex AI Gemini REST endpoint directly using
/// an API key (short-lived OAuth access token).
///
/// **Never ship in a mobile app.** Bundles the API key client-side; for demos
/// and server-side usage only. For production use [VertexProxyClient].
///
/// The API key passed as [apiKey] should be a short-lived OAuth 2.0 access
/// token in production, not a static credential. Vertex AI does not support
/// static API keys the same way as other Google APIs — the value is forwarded
/// as `Authorization: Bearer <apiKey>`.
///
/// Example:
/// ```dart
/// final client = VertexDirectClient(
///   apiKey: accessToken,
///   projectId: 'my-gcp-project',
///   location: 'europe-west1',
/// );
/// final stream = client.generate(
///   systemPrompt: systemPrompt,
///   messages: session.history.map((a) => a.message).toList(),
///   responseSchema: generativeStrategyResponseSchema(),
///   model: 'gemini-2.5-flash',
/// );
/// final json = await stream.first;
/// ```
class VertexDirectClient extends LlmClient {
  /// The OAuth access token (or API key for testing).
  final String apiKey;

  /// The GCP project ID.
  final String projectId;

  /// The Vertex AI region, e.g. `'europe-west1'` or `'us-central1'`.
  final String location;

  final http.Client _httpClient;

  /// Creates a [VertexDirectClient].
  ///
  /// Inject [httpClient] to use a test double (e.g. `MockClient` from
  /// `package:http/testing.dart`). If omitted, a real [http.Client] is used.
  VertexDirectClient({
    required this.apiKey,
    required this.projectId,
    required this.location,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Builds the Vertex AI streamGenerateContent URL for [model].
  Uri _buildUri(String model) {
    return Uri.parse(
      'https://$location-aiplatform.googleapis.com/v1/projects/$projectId'
      '/locations/$location/publishers/google/models/$model'
      ':streamGenerateContent',
    );
  }

  /// Maps a [Message] to Vertex AI's `contents[n]` payload shape.
  ///
  /// Vertex Gemini accepts `'user'` and `'model'` roles; [MessageRole.assistant]
  /// is mapped to `'model'` here. [MessageRole.system] should never appear in
  /// `messages` — system content goes through the dedicated `systemInstruction`.
  Map<String, dynamic> _messageToContent(Message message) {
    final role = switch (message.role) {
      MessageRole.user => 'user',
      MessageRole.assistant => 'model',
      MessageRole.system => 'user', // defensive — caller should not pass this
    };
    return {
      'role': role,
      'parts': [
        {'text': message.content},
      ],
    };
  }

  /// Parses the `Retry-After` header value into a [Duration], or returns
  /// `null` if the header is absent or not a valid integer.
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
    // Using async* so we can yield/throw naturally without StreamController
    // boilerplate.
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

    final payload = {
      'contents': messages.map(_messageToContent).toList(),
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
          'Authorization': 'Bearer $apiKey',
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

    // Map HTTP error status codes to LlmClientError subtypes.
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthError(
        'Vertex AI returned HTTP ${response.statusCode}: ${response.body}',
      );
    }

    if (response.statusCode == 429) {
      throw RateLimitError(
        'Vertex AI rate limit exceeded (HTTP 429)',
        retryAfter: _parseRetryAfter(response),
      );
    }

    if (response.statusCode >= 500) {
      throw NetworkError(
        'Vertex AI server error (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    // Parse the streamed JSON array response.
    // Vertex streamGenerateContent returns the full response as a JSON array
    // of chunk objects. We parse the array and concatenate the text from all
    // parts to reconstruct the full JSON output.
    List<dynamic> chunks;
    try {
      chunks = jsonDecode(response.body) as List<dynamic>;
    } catch (e) {
      throw SchemaError(
        'Failed to parse Vertex AI response envelope as JSON array: $e',
      );
    }

    // Concatenate all text parts across all chunks.
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
          'Failed to extract text from Vertex AI response chunk: $e',
        );
      }
    }

    final accumulated = buffer.toString();

    // Validate that the accumulated buffer is parseable JSON before emitting.
    // If not, the LLM returned non-JSON content despite the responseMimeType
    // constraint — surface as SchemaError.
    try {
      jsonDecode(accumulated);
    } catch (e) {
      throw SchemaError(
        'Vertex AI response text is not valid JSON: $e\n'
        'Raw text (first 500 chars): ${accumulated.substring(0, accumulated.length.clamp(0, 500))}',
      );
    }

    yield accumulated;
  }
}
