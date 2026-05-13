// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:genuiform/src/llm/gemini_api_client.dart';
import 'package:genuiform/src/llm/llm_client.dart';
import 'package:genuiform/src/models/message.dart';

/// Builds a single Gemini SSE event line wrapping [text] as the part text.
String _sseEvent(String text) {
  final payload = jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {'text': text},
          ],
        },
      },
    ],
  });
  return 'data: $payload\n\n';
}

/// Convenience wrapper: a 200 SSE response with a single event for [text].
String _sseResponse(String text) => _sseEvent(text);

GeminiApiClient _makeClient(MockClientHandler handler) => GeminiApiClient(
      apiKey: 'AIza-test-key',
      httpClient: MockClient(handler),
    );

void main() {
  group('GeminiApiClient — happy path', () {
    test('calls correct generativelanguage URL', () async {
      late Uri capturedUri;

      final client = _makeClient((request) async {
        capturedUri = request.url;
        return http.Response(
          _sseResponse('{"decision":"ask_step"}'),
          200,
        );
      });

      await client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      expect(capturedUri.host, 'generativelanguage.googleapis.com');
      expect(
        capturedUri.path,
        '/v1beta/models/gemini-2.5-flash:streamGenerateContent',
      );
      // SSE mode is required for incremental streaming.
      expect(capturedUri.queryParameters['alt'], 'sse');
    });

    test('sends x-goog-api-key header (no Bearer)', () async {
      late Map<String, String> capturedHeaders;

      final client = _makeClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(_sseResponse('{"ok":true}'), 200);
      });

      await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      expect(capturedHeaders['x-goog-api-key'], 'AIza-test-key');
      expect(capturedHeaders.containsKey('Authorization'), isFalse);
    });

    test('maps assistant role to model in contents', () async {
      late Map<String, dynamic> capturedBody;

      final client = _makeClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_sseResponse('{"ok":true}'), 200);
      });

      await client
          .generate(
            systemPrompt: 'sys',
            messages: [
              Message(role: MessageRole.user, content: 'hello'),
              Message(role: MessageRole.assistant, content: 'hi there'),
            ],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      final contents = capturedBody['contents'] as List<dynamic>;
      expect((contents[0] as Map)['role'], 'user');
      expect((contents[1] as Map)['role'], 'model');
    });

    test('sends systemInstruction and generationConfig', () async {
      late Map<String, dynamic> capturedBody;
      final schema = {
        'type': 'object',
        'properties': {
          'decision': {'type': 'string'},
        },
      };

      final client = _makeClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_sseResponse('{"ok":true}'), 200);
      });

      await client
          .generate(
            systemPrompt: 'You are a form designer.',
            messages: [],
            responseSchema: schema,
            model: 'gemini-2.5-flash',
            temperature: 0.3,
          )
          .first;

      final sysInstr =
          capturedBody['systemInstruction'] as Map<String, dynamic>;
      expect(
        (sysInstr['parts'] as List).first,
        containsPair('text', 'You are a form designer.'),
      );

      final genCfg = capturedBody['generationConfig'] as Map<String, dynamic>;
      expect(genCfg['temperature'], 0.3);
      expect(genCfg['responseMimeType'], 'application/json');
      expect(genCfg['responseSchema'], schema);
    });

    test('yields a single delta when the SSE response has one event',
        () async {
      final client = _makeClient(
        (request) async => http.Response(
          _sseResponse('{"decision":"ask_step","engagement":"strong"}'),
          200,
        ),
      );

      final deltas = await client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .toList();

      expect(deltas, ['{"decision":"ask_step","engagement":"strong"}']);
    });

    test('yields one delta per SSE event in the response body', () async {
      final body = _sseResponse('{"hello"') + _sseResponse(':1}');

      final client = _makeClient(
        (request) async => http.Response(body, 200),
      );

      final deltas = await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .toList();

      expect(deltas, ['{"hello"', ':1}']);
      expect(jsonDecode(deltas.join()), {'hello': 1});
    });
  });

  group('GeminiApiClient — SSE streaming', () {
    /// Encodes [text] as a single Gemini SSE `data:` event line.
    String _sseEvent(String text) {
      final payload = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          },
        ],
      });
      return 'data: $payload\n\n';
    }

    test('appends ?alt=sse to the request URL', () async {
      late Uri capturedUri;

      final mock = MockClient.streaming((request, _) async {
        capturedUri = request.url;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            utf8.encode(_sseEvent('{"ok":true}')),
          ]),
          200,
        );
      });

      final client = GeminiApiClient(apiKey: 'AIza-test', httpClient: mock);
      await client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: const {},
            model: 'gemini-2.5-flash',
          )
          .toList();

      expect(capturedUri.queryParameters['alt'], 'sse');
      expect(
        capturedUri.path,
        '/v1beta/models/gemini-2.5-flash:streamGenerateContent',
      );
    });

    test('yields one delta per SSE event as bytes arrive', () async {
      final mock = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            utf8.encode(_sseEvent('{"hello')),
            utf8.encode(_sseEvent('":1}')),
          ]),
          200,
        );
      });

      final client = GeminiApiClient(apiKey: 'AIza-test', httpClient: mock);
      final deltas = await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: const {},
            model: 'gemini-2.5-flash',
          )
          .toList();

      expect(deltas, equals(['{"hello', '":1}']));
      expect(deltas.join(), equals('{"hello":1}'));
    });

    test('handles SSE events split across byte chunks', () async {
      final fullEvent = _sseEvent('{"split":true}');
      final midpoint = fullEvent.length ~/ 2;
      final chunkA = utf8.encode(fullEvent.substring(0, midpoint));
      final chunkB = utf8.encode(fullEvent.substring(midpoint));

      final mock = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([chunkA, chunkB]),
          200,
        );
      });

      final client = GeminiApiClient(apiKey: 'AIza-test', httpClient: mock);
      final deltas = await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: const {},
            model: 'gemini-2.5-flash',
          )
          .toList();

      expect(deltas.join(), equals('{"split":true}'));
    });
  });

  group('GeminiApiClient — cachedContent', () {
    test('generate with cachedContent sends top-level cachedContent field and no systemInstruction',
        () async {
      late Map<String, dynamic> capturedBody;

      final client = _makeClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_sseResponse('{"ok":true}'), 200);
      });

      await client
          .generate(
            systemPrompt: 'ignored because cached',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
            cachedContent: 'cachedContents/foo',
          )
          .first;

      expect(capturedBody.containsKey('cachedContent'), isTrue);
      expect(capturedBody['cachedContent'], 'cachedContents/foo');
      expect(capturedBody.containsKey('systemInstruction'), isFalse);
      expect(capturedBody.containsKey('contents'), isTrue);
      expect(capturedBody.containsKey('generationConfig'), isTrue);
    });

    test('generate without cachedContent sends systemInstruction as before',
        () async {
      late Map<String, dynamic> capturedBody;

      final client = _makeClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_sseResponse('{"ok":true}'), 200);
      });

      await client
          .generate(
            systemPrompt: 'You are a form designer.',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      expect(capturedBody.containsKey('systemInstruction'), isTrue);
      expect(capturedBody.containsKey('cachedContent'), isFalse);
    });

    test('createCachedContent POSTs to correct URL with correct body and returns name',
        () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;
      late Map<String, String> capturedHeaders;

      final client = GeminiApiClient(
        apiKey: 'AIza-test-key',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          capturedHeaders = request.headers;
          return http.Response(
            jsonEncode({'name': 'cachedContents/abc123', 'expireTime': '2026-01-01T00:00:00Z'}),
            200,
          );
        }),
      );

      final name = await client.createCachedContent(
        systemInstruction: 'You are a form designer.',
        model: 'gemini-2.5-flash',
        ttl: const Duration(seconds: 300),
      );

      expect(name, 'cachedContents/abc123');
      expect(capturedUri.path, '/v1beta/cachedContents');
      expect(capturedBody['model'], 'models/gemini-2.5-flash');
      expect(capturedBody['ttl'], '300s');
      final sysInstr = capturedBody['systemInstruction'] as Map<String, dynamic>;
      expect(
        (sysInstr['parts'] as List).first,
        containsPair('text', 'You are a form designer.'),
      );
      expect(capturedHeaders['x-goog-api-key'], 'AIza-test-key');
    });

    test('createCachedContent throws CacheError on non-2xx response and sanitizes', () async {
      final client = GeminiApiClient(
        apiKey: 'AIza-test-key',
        httpClient: MockClient((_) async =>
            http.Response('{"error":"quota_exceeded_secret_leak"}', 429)),
      );

      final call = client.createCachedContent(
        systemInstruction: 'sys',
        model: 'gemini-2.5-flash',
      );

      await expectLater(
        call,
        throwsA(isA<CacheError>().having(
          (e) => e.message,
          'message',
          isNot(contains('quota_exceeded_secret_leak')),
        )),
      );
    });

    test('HTTP 404 on cachedContent reference maps to CacheError', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"not found"}', 404),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
          cachedContent: 'cachedContents/expired',
        ),
        emitsError(isA<CacheError>()),
      );
    });

    test('deleteCachedContent sends DELETE to correct URL', () async {
      late Uri capturedUri;
      late String capturedMethod;
      late Map<String, String> capturedHeaders;

      final client = GeminiApiClient(
        apiKey: 'AIza-test-key',
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          capturedMethod = request.method;
          capturedHeaders = request.headers;
          return http.Response('', 200);
        }),
      );

      await client.deleteCachedContent('cachedContents/abc123');

      expect(capturedMethod, 'DELETE');
      expect(capturedUri.path, '/v1beta/cachedContents/abc123');
      expect(capturedHeaders['x-goog-api-key'], 'AIza-test-key');
    });

    test('deleteCachedContent swallows 404 without throwing', () async {
      final client = GeminiApiClient(
        apiKey: 'AIza-test-key',
        httpClient: MockClient((_) async => http.Response('', 404)),
      );

      // Should not throw
      await client.deleteCachedContent('cachedContents/expired');
    });
  });

  group('GeminiApiClient — error handling', () {
    test('HTTP 401 maps to AuthError and sanitizes message', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"unauthorized_secret_leak"}', 401),
      );

      final call = client.generate(
        systemPrompt: 'sys',
        messages: [],
        responseSchema: {},
        model: 'gemini-2.5-flash',
      );

      await expectLater(
        call,
        emitsError(isA<AuthError>().having(
          (e) => e.message,
          'message',
          isNot(contains('unauthorized_secret_leak')),
        )),
      );
    });

    test('HTTP 403 maps to AuthError and sanitizes message', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"forbidden_secret_leak"}', 403),
      );

      final call = client.generate(
        systemPrompt: 'sys',
        messages: [],
        responseSchema: {},
        model: 'gemini-2.5-flash',
      );

      await expectLater(
        call,
        emitsError(isA<AuthError>().having(
          (e) => e.message,
          'message',
          isNot(contains('forbidden_secret_leak')),
        )),
      );
    });

    test('HTTP 429 maps to RateLimitError with parsed Retry-After', () async {
      final client = _makeClient(
        (request) async => http.Response(
          '{"error":"rate limit"}',
          429,
          headers: {'retry-after': '60'},
        ),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        emitsError(
          isA<RateLimitError>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 60),
          ),
        ),
      );
    });

    test('HTTP 500 maps to NetworkError and sanitizes message', () async {
      final client = _makeClient(
        (request) async => http.Response('boom_secret_leak', 500),
      );

      final call = client.generate(
        systemPrompt: 'sys',
        messages: [],
        responseSchema: {},
        model: 'gemini-2.5-flash',
      );

      await expectLater(
        call,
        emitsError(isA<NetworkError>().having(
          (e) => e.message,
          'message',
          isNot(contains('boom_secret_leak')),
        )),
      );
    });

    test('malformed SSE event JSON maps to SchemaError and sanitizes message', () async {
      const malformedData = 'this-is-not-json-secret-leak';
      final client = _makeClient(
        (request) async => http.Response(
          'data: $malformedData\n\n',
          200,
        ),
      );

      final call = client.generate(
        systemPrompt: 'sys',
        messages: [],
        responseSchema: {},
        model: 'gemini-2.5-flash',
      );

      await expectLater(
        call,
        emitsError(isA<SchemaError>().having(
          (e) => e.message,
          'message',
          isNot(contains(malformedData)),
        )),
      );
    });

    test('non-SSE 200 body yields no deltas (consumer detects empty)',
        () async {
      // The client is now a transport — it does not validate that the body is
      // SSE. A 200 response with no `data:` lines simply produces no deltas;
      // it is the consumer's job to detect "no output" and fail accordingly.
      final client = _makeClient(
        (request) async => http.Response('this is not sse at all', 200),
      );

      final deltas = await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .toList();

      expect(deltas, isEmpty);
    });

    test('http.ClientException maps to NetworkError', () async {
      final client = GeminiApiClient(
        apiKey: 'AIza-test',
        httpClient: MockClient((_) async {
          throw http.ClientException('connection refused');
        }),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        emitsError(isA<NetworkError>()),
      );
    });
  });
}
