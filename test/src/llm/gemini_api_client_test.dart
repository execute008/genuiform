// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:genuiform/src/llm/gemini_api_client.dart';
import 'package:genuiform/src/llm/llm_client.dart';
import 'package:genuiform/src/models/message.dart';

/// Builds a well-formed Gemini streamGenerateContent response wrapping [text].
String _geminiResponse(String text) => jsonEncode([
      {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': text},
              ],
            },
          },
        ],
      },
    ]);

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
          _geminiResponse('{"decision":"ask_step"}'),
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

      expect(
        capturedUri.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.5-flash:streamGenerateContent',
      );
    });

    test('sends x-goog-api-key header (no Bearer)', () async {
      late Map<String, String> capturedHeaders;

      final client = _makeClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(_geminiResponse('{"ok":true}'), 200);
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
        return http.Response(_geminiResponse('{"ok":true}'), 200);
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
        return http.Response(_geminiResponse('{"ok":true}'), 200);
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

    test('emits a single complete JSON string from stream', () async {
      final client = _makeClient(
        (request) async => http.Response(
          _geminiResponse('{"decision":"ask_step","engagement":"strong"}'),
          200,
        ),
      );

      final result = await client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      expect(result, '{"decision":"ask_step","engagement":"strong"}');
    });

    test('buffers multiple chunk texts into a single emission', () async {
      final multiChunkResponse = jsonEncode([
        {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '{"hello"'},
                ],
              },
            },
          ],
        },
        {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': ':1}'},
                ],
              },
            },
          ],
        },
      ]);

      final client = _makeClient(
        (request) async => http.Response(multiChunkResponse, 200),
      );

      final result = await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      expect(jsonDecode(result), {'hello': 1});
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

  group('GeminiApiClient — error handling', () {
    test('HTTP 401 maps to AuthError', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"unauthorized"}', 401),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        emitsError(isA<AuthError>()),
      );
    });

    test('HTTP 403 maps to AuthError', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"forbidden"}', 403),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        emitsError(isA<AuthError>()),
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

    test('HTTP 500 maps to NetworkError', () async {
      final client = _makeClient(
        (request) async => http.Response('boom', 500),
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

    test('non-JSON inner text maps to SchemaError', () async {
      final client = _makeClient(
        (request) async => http.Response(
          _geminiResponse('not valid json {{{'),
          200,
        ),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        emitsError(isA<SchemaError>()),
      );
    });

    test('malformed envelope maps to SchemaError', () async {
      final client = _makeClient(
        (request) async => http.Response('this is not json at all', 200),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        emitsError(isA<SchemaError>()),
      );
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
