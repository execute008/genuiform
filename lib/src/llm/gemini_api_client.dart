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
/// ### Streaming
///
/// The endpoint is called with `?alt=sse` so the response is a Server-Sent
/// Events stream. [generate] yields one text delta per SSE event as bytes
/// arrive — consumers must concatenate the deltas to reconstruct the final
/// JSON.
///
/// Example:
/// ```dart
/// final client = GeminiApiClient(apiKey: 'AIza...');
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
class GeminiApiClient extends LlmClient {
  /// The Gemini API key (typically `AIza...`-prefixed).
  final String apiKey;

  final http.Client _httpClient;

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Creates a [GeminiApiClient].
  ///
  /// Inject [httpClient] to use a test double (e.g. `MockClient.streaming`
  /// from `package:http/testing.dart`). If omitted, a real [http.Client] is
  /// used.
  GeminiApiClient({
    required this.apiKey,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Uri _buildUri(String model) {
    return Uri.parse(
      '$_baseUrl/models/$model'
      ':streamGenerateContent',
    ).replace(queryParameters: {'alt': 'sse'});
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
    Map<String, dynamic>? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    required String model,
    double temperature = 0.7,
    String? cachedContent,
  }) {
    assert(
      (responseSchema == null) != (responseJsonSchema == null),
      'GeminiApiClient.generate: pass exactly one of responseSchema / '
      'responseJsonSchema.',
    );
    return _generateAsync(
      systemPrompt: systemPrompt,
      messages: messages,
      responseSchema: responseSchema,
      responseJsonSchema: responseJsonSchema,
      model: model,
      temperature: temperature,
      cachedContent: cachedContent,
    );
  }

  Stream<String> _generateAsync({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic>? responseSchema,
    required Map<String, dynamic>? responseJsonSchema,
    required String model,
    required double temperature,
    required String? cachedContent,
  }) async* {
    final uri = _buildUri(model);

    // Gemini AI Studio's :streamGenerateContent rejects empty `contents` with
    // HTTP 400. When the caller has only a system prompt to send, synthesize
    // a single user turn so the request is well-formed.
    final effectiveMessages = messages.isEmpty
        ? [const Message(role: MessageRole.user, content: 'Begin.')]
        : messages;

    final Map<String, dynamic> payload;
    if (cachedContent != null) {
      // When a cachedContent reference is provided, systemInstruction is
      // already baked into the cache — omit it from the wire payload.
      payload = {
        'cachedContent': cachedContent,
        'contents': effectiveMessages.map(_messageToContent).toList(),
        'generationConfig': {
          'temperature': temperature,
          'responseMimeType': 'application/json',
          if (responseSchema != null) 'responseSchema': responseSchema,
          if (responseJsonSchema != null)
            'responseJsonSchema': responseJsonSchema,
        },
      };
    } else {
      payload = {
        'contents': effectiveMessages.map(_messageToContent).toList(),
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'generationConfig': {
          'temperature': temperature,
          'responseMimeType': 'application/json',
          if (responseSchema != null) 'responseSchema': responseSchema,
          if (responseJsonSchema != null)
            'responseJsonSchema': responseJsonSchema,
        },
      };
    }

    final request = http.Request('POST', uri);
    request.headers['x-goog-api-key'] = apiKey;
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
        throw AuthError('Gemini API returned HTTP $status: $body');
      }
      if (status == 429) {
        throw RateLimitError(
          'Gemini API rate limit exceeded (HTTP 429)',
          retryAfter: _parseRetryAfter(response.headers),
        );
      }
      if (status >= 500) {
        throw NetworkError(
          'Gemini API server error (HTTP $status): $body',
        );
      }
      // 404 on a cachedContent reference means the cache has expired.
      if (status == 404 && cachedContent != null) {
        throw CacheError(
          'Gemini cached content not found (HTTP 404): $cachedContent',
        );
      }
      throw SchemaError(
        'Gemini API rejected request (HTTP $status): $body',
      );
    }

    // Parse the Server-Sent Events stream incrementally. Each `data: {...}`
    // line is one Gemini chunk; we extract its text part and yield it as a
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
          'Failed to parse Gemini SSE event as JSON: $e',
        );
      }

      final delta = _extractTextDelta(chunkMap);
      if (delta.isNotEmpty) {
        yield delta;
      }
    }
  }

  /// Extracts concatenated text from `candidates[*].content.parts[*].text`
  /// in a single Gemini chunk. Returns an empty string if no text parts are
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
        'Failed to extract text from Gemini SSE event: $e',
      );
    }
  }

  @override
  Future<String> createCachedContent({
    required String systemInstruction,
    required String model,
    Duration ttl = const Duration(seconds: 300),
  }) async {
    final uri = Uri.parse('$_baseUrl/cachedContents');
    final body = jsonEncode({
      'model': 'models/$model',
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'ttl': '${ttl.inSeconds}s',
    });

    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: body,
      );
    } on SocketException catch (e) {
      throw CacheError('Socket error creating cached content: ${e.message}');
    } on http.ClientException catch (e) {
      throw CacheError(
          'HTTP client error creating cached content: ${e.message}');
    } on TimeoutException catch (_) {
      throw const CacheError('Request timed out creating cached content');
    } catch (e) {
      throw CacheError('Unexpected error creating cached content: $e');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CacheError(
        'Failed to create cached content (HTTP ${response.statusCode}): '
        '${response.body}',
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw CacheError(
          'Failed to parse createCachedContent response: $e');
    }

    final name = json['name'] as String?;
    if (name == null) {
      throw const CacheError(
          'createCachedContent response missing "name" field');
    }
    return name;
  }

  @override
  Future<void> deleteCachedContent(String name) async {
    final uri = Uri.parse('$_baseUrl/$name');
    try {
      final response = await _httpClient.delete(
        uri,
        headers: {'x-goog-api-key': apiKey},
      );
      // 404 means it already expired — that's fine. Any other non-2xx is also
      // swallowed since deletion is best-effort.
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      if (response.statusCode == 404) return;
      // Log but swallow other errors.
      // ignore: avoid_print
      print(
        'GeminiApiClient: deleteCachedContent "$name" returned '
        'HTTP ${response.statusCode} — ignored.',
      );
    } catch (e) {
      // Best-effort: swallow all errors.
      // ignore: avoid_print
      print('GeminiApiClient: deleteCachedContent "$name" failed: $e — ignored.');
    }
  }
}
