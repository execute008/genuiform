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
/// ### Streaming
///
/// The endpoint is called with `?alt=sse` so the response is a Server-Sent
/// Events stream. [generate] yields one text delta per SSE event as bytes
/// arrive — consumers must concatenate the deltas to reconstruct the final
/// JSON.
///
/// Example:
/// ```dart
/// final client = VertexDirectClient(
///   apiKey: accessToken,
///   projectId: 'my-gcp-project',
///   location: 'europe-west1',
/// );
/// final buffer = StringBuffer();
/// await for (final delta in client.generate(
///   systemPrompt: systemPrompt,
///   messages: session.history.map((a) => a.message).toList(),
///   responseSchema: generativeStrategyResponseSchema(),
///   model: 'gemini-2.5-flash',
/// )) {
///   buffer.write(delta);
/// }
/// final json = jsonDecode(buffer.toString());
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
  /// Inject [httpClient] to use a test double (e.g. `MockClient.streaming`
  /// from `package:http/testing.dart`). If omitted, a real [http.Client] is
  /// used.
  VertexDirectClient({
    required this.apiKey,
    required this.projectId,
    required this.location,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Builds the Vertex AI streamGenerateContent URL for [model], with
  /// `?alt=sse` so the response is delivered as Server-Sent Events.
  Uri _buildUri(String model) {
    return Uri.parse(
      'https://$location-aiplatform.googleapis.com/v1/projects/$projectId'
      '/locations/$location/publishers/google/models/$model'
      ':streamGenerateContent',
    ).replace(queryParameters: {'alt': 'sse'});
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
  Duration? _parseRetryAfter(Map<String, String> headers) {
    final raw = headers['retry-after'];
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

    final request = http.Request('POST', uri);
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode(payload);

    http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } on SocketException catch (e) {
      throw NetworkError('Socket error: ${e.message}', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkError('HTTP client error: ${e.message}', cause: e);
    } on TimeoutException catch (e) {
      throw NetworkError('Request timed out', cause: e);
    } catch (e) {
      throw UnknownError('Unexpected error during HTTP request', cause: e);
    }

    final status = response.statusCode;
    if (status != 200) {
      final body = await response.stream.bytesToString();
      if (status == 401 || status == 403) {
        throw AuthError('Vertex AI returned HTTP $status: $body');
      }
      if (status == 429) {
        throw RateLimitError(
          'Vertex AI rate limit exceeded (HTTP 429)',
          retryAfter: _parseRetryAfter(response.headers),
        );
      }
      if (status >= 500) {
        throw NetworkError(
          'Vertex AI server error (HTTP $status): $body',
        );
      }
      throw SchemaError(
        'Vertex AI rejected request (HTTP $status): $body',
      );
    }

    // Parse the Server-Sent Events stream incrementally. Each `data: {...}`
    // line is one Vertex chunk; we extract its text part and yield it as a
    // delta. Consumers concatenate deltas to reconstruct the full JSON.
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.startsWith(':')) continue; // SSE comment / keep-alive
      if (!line.startsWith('data:')) continue;

      final data = line.substring(5).trim();
      if (data.isEmpty) continue;

      Map<String, dynamic> chunkMap;
      try {
        chunkMap = jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        throw SchemaError(
          'Failed to parse Vertex SSE event as JSON: $e',
        );
      }

      final delta = _extractTextDelta(chunkMap);
      if (delta.isNotEmpty) {
        yield delta;
      }
    }
  }

  /// Extracts concatenated text from `candidates[*].content.parts[*].text`
  /// in a single Vertex chunk. Returns an empty string if no text parts are
  /// present (e.g. safety-rating-only events).
  static String _extractTextDelta(Map<String, dynamic> chunkMap) {
    try {
      final candidates = chunkMap['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return '';

      final buffer = StringBuffer();
      for (final candidate in candidates) {
        final content = (candidate as Map<String, dynamic>)['content']
            as Map<String, dynamic>?;
        if (content == null) continue;
        final parts = content['parts'] as List<dynamic>?;
        if (parts == null) continue;
        for (final part in parts) {
          final text = (part as Map<String, dynamic>)['text'] as String?;
          if (text != null) buffer.write(text);
        }
      }
      return buffer.toString();
    } catch (e) {
      throw SchemaError(
        'Failed to extract text from Vertex SSE event: $e',
      );
    }
  }
}
