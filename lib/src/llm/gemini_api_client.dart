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
  final String _apiKey;

  /// Returns the API key.
  String get apiKey => _apiKey;

  final http.Client _httpClient;

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  /// Creates a [GeminiApiClient].
  ///
  /// Inject [httpClient] to use a test double (e.g. `MockClient.streaming`
  /// from `package:http/testing.dart`). If omitted, a real [http.Client] is
  /// used.
  GeminiApiClient({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

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
    request.headers['x-goog-api-key'] = _apiKey;
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
      // ignore: avoid_print
      print('GeminiApiClient: HTTP $status error: $body');

      if (status == 401 || status == 403) {
        throw AuthError(
          'Gemini API returned HTTP $status. Check server logs for details.',
        );
      }
      if (status == 429) {
        throw RateLimitError(
          'Gemini API rate limit exceeded (HTTP 429)',
          retryAfter: _parseRetryAfter(response.headers),
        );
      }
      if (status >= 500) {
        throw NetworkError(
          'Gemini API server error (HTTP $status). Check server logs for details.',
        );
      }
      // 404 on a cachedContent reference means the cache has expired.
      if (status == 404 && cachedContent != null) {
        // ignore: avoid_print
        print('GeminiApiClient: cachedContent not found: $cachedContent');
        throw CacheError(
          'Gemini cached content not found (HTTP 404): $cachedContent',
        );
      }
      throw SchemaError(
        'Gemini API rejected request (HTTP $status). Check server logs for details.',
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
        // ignore: avoid_print
        print('GeminiApiClient: Failed to parse SSE event: $data');
        throw SchemaError(
          'Failed to parse Gemini SSE event as JSON. Check server logs for details.',
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
      // ignore: avoid_print
      print('GeminiApiClient: Failed to extract text from chunk: $chunkMap');
      throw SchemaError(
        'Failed to extract text from Gemini SSE event. Check server logs for details.',
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
          'x-goog-api-key': _apiKey,
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
        headers: {'x-goog-api-key': _apiKey},
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

  /// Generates a tiny, scenario-themed SVG mascot via a one-shot call to
  /// `gemini-2.5-flash:generateContent`. Returns the raw `<svg>...</svg>`
  /// string on success, or `''` on any failure (network, bad response,
  /// no extractable SVG block).
  ///
  /// The returned SVG is **static** — flutter_svg does not execute CSS
  /// animations, so any motion is applied Flutter-side via a Transform
  /// wrapper. The prompt explicitly forbids `<style>` / `<animate>` tags.
  ///
  /// Failures are logged with `print()` so the cause is visible in the
  /// browser DevTools console — silent emptiness is hard to debug.
  Future<String> generateMascotSvg(String scenarioKey) async {
    // Per-call nonce defeats Gemini's response cache so each press of "Next"
    // gets a fresh design instead of the same mascot in different rotations.
    final nonce = DateTime.now().microsecondsSinceEpoch % 1000000;

    final prompt = '''
Generate a tiny SVG mascot character. Theme: $scenarioKey
Variation seed: $nonce — use this to pick a unique pose, expression, and accent-color combo. Different seed must produce a visibly different mascot.

Themes and what to draw:
- lead_qualification = a small suited businessman with a briefcase, confident pose
- gymgeist_onboarding = a tiny athlete holding a dumbbell or lightning bolt
- newsletter_signup = a friendly envelope character with eyes
- medical_intake = a small doctor with a stethoscope or red cross

STRICT OUTPUT RULES — read carefully:
- Return ONLY valid SVG. No markdown fences, no prose, no backticks.
- Start with <svg and end with </svg>. Closing </svg> is REQUIRED.
- Output MUST be under 1200 characters total. Simplify if approaching the limit.
- Use AT MOST 12 shape elements total. Prefer circle / rect / ellipse over <path>.
- Root attributes: viewBox="0 0 120 120" width="120" height="120" xmlns="http://www.w3.org/2000/svg"

ABSOLUTELY FORBIDDEN — these break the renderer:
- NO <style> blocks. NO CSS. NO @keyframes. NO class="..." attributes.
- NO <animate>, <animateTransform>, <animateMotion> tags.
- NO <text>, <image>, <use href>, external href / xlink:href references.
- NO comments. NO XML processing instructions. NO DOCTYPE.

VISUAL RULES:
- Colors only from: #C8BFFF #ECB8CD #443996 #E6E1E9 #9FD4A3 #FFD89C
- The mascot sits on a DARK background. Light/bright fills only — at least 70% of the visible area must use #C8BFFF / #ECB8CD / #E6E1E9 / #9FD4A3 / #FFD89C. #443996 is OK only as accent strokes.
- Use the `fill="#..."` attribute directly on each shape (no CSS selectors).

OUTPUT SHAPE: just `<svg ...>` then 8-12 shape elements then `</svg>`. Nothing else.
''';

    try {
      final uri = Uri.parse(
        '$_baseUrl/models/gemini-2.5-flash:generateContent',
      );

      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 1.0,
          'maxOutputTokens': 4096,
        },
      });

      final response = await _httpClient
          .post(
            uri,
            headers: {
              'x-goog-api-key': _apiKey,
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final preview = response.body.substring(
          0,
          response.body.length.clamp(0, 400),
        );
        // ignore: avoid_print
        print(
          'GeminiApiClient.generateMascotSvg: HTTP ${response.statusCode} '
          '— body: $preview',
        );
        return '';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        // ignore: avoid_print
        print(
          'GeminiApiClient.generateMascotSvg: no candidates — body: '
          '${response.body}',
        );
        return '';
      }

      final content = (candidates[0] as Map<String, dynamic>)['content']
          as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        // ignore: avoid_print
        print(
          'GeminiApiClient.generateMascotSvg: no parts (likely MAX_TOKENS '
          'or safety) — candidate: ${candidates[0]}',
        );
        return '';
      }

      final text = (parts[0] as Map<String, dynamic>)['text'] as String?;
      if (text == null || text.isEmpty) return '';

      // Extract <svg ... </svg> from anywhere in the response. Gemini often
      // wraps SVG in ```svg ... ``` fences or leads with prose; a strict
      // startsWith/endsWith check rejects those silently.
      final match = RegExp(
        r'<svg[\s\S]*?</svg>',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) return match.group(0)!;

      // Salvage path: model started an <svg> but ran out of tokens before
      // closing it (MAX_TOKENS mid-stream). Take from the opening tag, trim
      // any half-finished trailing element by keeping only up to the last
      // complete `>` character, and append `</svg>`. Better a possibly-ugly
      // mascot than nothing.
      final openIdx = text.toLowerCase().indexOf('<svg');
      if (openIdx >= 0) {
        var partial = text.substring(openIdx);
        final lastClose = partial.lastIndexOf('>');
        if (lastClose >= 0) {
          partial = partial.substring(0, lastClose + 1);
          final salvaged = '$partial</svg>';
          // ignore: avoid_print
          print(
            'GeminiApiClient.generateMascotSvg: salvaged truncated SVG '
            '(${salvaged.length} chars; raw was ${text.length}, no </svg>).',
          );
          return salvaged;
        }
      }

      final preview = text.substring(0, text.length.clamp(0, 1500));
      // ignore: avoid_print
      print(
        'GeminiApiClient.generateMascotSvg: no <svg> block in response '
        '(text length ${text.length}) — raw text: $preview',
      );
      return '';
    } catch (e, st) {
      // ignore: avoid_print
      print('GeminiApiClient.generateMascotSvg: $e\n$st');
      return '';
    }
  }
}
