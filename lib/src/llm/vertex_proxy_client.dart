import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/message.dart';
import 'llm_client.dart';

/// A [LlmClient] that proxies Vertex AI Gemini requests through a server-side
/// function (e.g. a Firebase Cloud Function), keeping the GCP service account
/// credentials off the client device.
///
/// This is the **production-ready transport** for shipped Flutter apps that
/// need Vertex AI specifically (rather than the public AI Studio Gemini API,
/// which [GeminiApiClient] handles). Vertex AI has no static client-side API
/// key, so the only safe paths are this proxy or `FirebaseVertexAI.instance`
/// from `package:firebase_vertex_ai`.
///
/// The proxy is expected to:
///
/// 1. Validate the bearer token returned by [authProvider] (typically a
///    Firebase Auth ID token).
/// 2. Forward the JSON payload as-is to Vertex AI's
///    `:streamGenerateContent` endpoint, attaching its own service-account
///    credentials.
/// 3. Return the Vertex response body verbatim (a Server-Sent Events stream
///    of `data: {...}` lines from `:streamGenerateContent`).
///
/// A reference Firebase Function implementing this contract ships in
/// `examples/firebase-proxy/index.ts` (~30 lines).
///
/// Example (using Firebase Auth to supply the user ID token):
/// ```dart
/// final client = VertexProxyClient(
///   endpoint: 'https://europe-west1-gymgeist.cloudfunctions.net/genuiformProxy',
///   authProvider: () async => await FirebaseAuth.instance.currentUser?.getIdToken(),
/// );
/// ```
class VertexProxyClient extends LlmClient {
  /// The full URL of the proxy Cloud Function.
  final String endpoint;

  /// Async callback that returns a bearer token for the current user.
  ///
  /// Returning `null` means the user is unauthenticated; the client will
  /// throw an [AuthError] without making the network call.
  final Future<String?> Function() authProvider;

  final http.Client _httpClient;

  /// Creates a [VertexProxyClient].
  ///
  /// [httpClient] may be injected for testing; defaults to [http.Client].
  VertexProxyClient({
    required this.endpoint,
    required this.authProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

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
      'VertexProxyClient.generate: pass exactly one of responseSchema / '
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
    final token = await authProvider();
    if (token == null || token.isEmpty) {
      throw const AuthError(
        'VertexProxyClient: authProvider returned null/empty bearer token',
      );
    }

    final payload = {
      'systemPrompt': systemPrompt,
      'messages': messages.map((m) => m.toJson()).toList(),
      if (responseSchema != null) 'responseSchema': responseSchema,
      if (responseJsonSchema != null) 'responseJsonSchema': responseJsonSchema,
      'model': model,
      'temperature': temperature,
      // TODO(proxy): the server-side proxy function needs to forward
      // cachedContent to Vertex AI's :streamGenerateContent endpoint.
      if (cachedContent != null) 'cachedContent': cachedContent,
    };

    http.Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
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
      throw UnknownError(
        'Unexpected error during proxy HTTP request',
        cause: e,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthError(
        'Proxy returned HTTP ${response.statusCode}. '
        'Check server logs for details.',
      );
    }
    if (response.statusCode == 429) {
      final retryAfterRaw = response.headers['retry-after'];
      final retryAfter = retryAfterRaw == null
          ? null
          : Duration(seconds: int.tryParse(retryAfterRaw) ?? 0);
      throw RateLimitError(
        'Proxy rate limit exceeded (HTTP 429)',
        retryAfter: retryAfter,
      );
    }
    if (response.statusCode >= 500) {
      throw NetworkError(
        'Proxy server error (HTTP ${response.statusCode}). '
        'Check server logs for details.',
      );
    }
    if (response.statusCode >= 400) {
      throw UnknownError(
        'Proxy returned HTTP ${response.statusCode}. '
        'Check server logs for details.',
      );
    }

    // The proxy is expected to return Vertex's response body verbatim:
    // a JSON array of chunk objects, each with candidates[].content.parts[].text.
    List<dynamic> chunks;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is List) {
        chunks = decoded;
      } else if (decoded is Map<String, dynamic>) {
        // Some proxy implementations may wrap the array in a single-key
        // object; tolerate that shape too.
        chunks = (decoded['response'] ?? decoded['chunks'] ?? [decoded])
            as List<dynamic>;
      } else {
        throw const FormatException('Unexpected envelope type');
      }
    } catch (e) {
      throw SchemaError(
        'Failed to parse proxy response envelope as JSON: $e',
      );
    }

    final buffer = StringBuffer();
    for (final chunk in chunks) {
      try {
        final chunkMap = chunk as Map<String, dynamic>;
        final candidates = chunkMap['candidates'] as List<dynamic>;
        for (final candidate in candidates) {
          final content =
              (candidate as Map<String, dynamic>)['content']
                  as Map<String, dynamic>;
          final parts = content['parts'] as List<dynamic>;
          for (final part in parts) {
            final text = (part as Map<String, dynamic>)['text'] as String;
            buffer.write(text);
          }
        }
      } catch (e) {
        throw SchemaError(
          'Failed to extract text from proxy response chunk: $e',
        );
      }
    }

    final accumulated = buffer.toString();
    try {
      jsonDecode(accumulated);
    } catch (e) {
      throw SchemaError(
        'Proxy response text is not valid JSON: $e',
      );
    }

    yield accumulated;
  }

  /// Not implemented — [VertexProxyClient] does not support direct REST calls
  /// to cachedContents. Vertex AI calls from Flutter clients must go through
  /// `FirebaseVertexAI.instance` or the server-side proxy. Add a
  /// `/cachedContents` endpoint to the proxy function if needed.
  @override
  Future<String> createCachedContent({
    required String systemInstruction,
    required String model,
    Duration ttl = const Duration(seconds: 300),
  }) {
    throw UnimplementedError(
      'VertexProxyClient: cachedContents not yet implemented. '
      'Add a /cachedContents endpoint to the proxy function.',
    );
  }

  /// Not implemented — see [createCachedContent] for rationale.
  @override
  Future<void> deleteCachedContent(String name) {
    throw UnimplementedError(
      'VertexProxyClient: cachedContents not yet implemented. '
      'Add a /cachedContents endpoint to the proxy function.',
    );
  }
}
