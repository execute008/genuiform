// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:genuiform/src/llm/vertex_direct_client.dart';
import 'package:genuiform/src/llm/llm_client.dart';
import 'package:genuiform/src/models/message.dart';

/// Builds a well-formed Vertex streamGenerateContent response wrapping [text].
String _vertexResponse(String text) => jsonEncode([
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

VertexDirectClient _makeClient(MockClientHandler handler) =>
    VertexDirectClient(
      apiKey: 'test-key',
      projectId: 'test-proj',
      location: 'europe-west1',
      httpClient: MockClient(handler),
    );

void main() {
  group('VertexDirectClient — happy path', () {
    test('calls correct Vertex URL', () async {
      late Uri capturedUri;

      final client = _makeClient((request) async {
        capturedUri = request.url;
        return http.Response(
          _vertexResponse('{"decision":"ask_step","engagement":"strong"}'),
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
        startsWith(
          'https://europe-west1-aiplatform.googleapis.com/v1/projects/test-proj/'
          'locations/europe-west1/publishers/google/models/gemini-2.5-flash'
          ':streamGenerateContent',
        ),
      );
    });

    test('sends Bearer auth header', () async {
      late Map<String, String> capturedHeaders;

      final client = _makeClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          _vertexResponse('{"ok":true}'),
          200,
        );
      });

      await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      expect(capturedHeaders['Authorization'], 'Bearer test-key');
    });

    test('sends Content-Type: application/json', () async {
      late Map<String, String> capturedHeaders;

      final client = _makeClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          _vertexResponse('{"ok":true}'),
          200,
        );
      });

      await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      expect(
        capturedHeaders['Content-Type'],
        contains('application/json'),
      );
    });

    test('maps messages to Vertex contents format', () async {
      late Map<String, dynamic> capturedBody;

      final client = _makeClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          _vertexResponse('{"ok":true}'),
          200,
        );
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
      expect(contents, hasLength(2));
      final first = contents[0] as Map<String, dynamic>;
      final second = contents[1] as Map<String, dynamic>;
      expect(first['role'], 'user');
      expect(
        (first['parts'] as List<dynamic>).first,
        containsPair('text', 'hello'),
      );
      expect(second['role'], 'model');
    });

    test('sends systemInstruction in payload', () async {
      late Map<String, dynamic> capturedBody;

      final client = _makeClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          _vertexResponse('{"ok":true}'),
          200,
        );
      });

      await client
          .generate(
            systemPrompt: 'You are a form designer.',
            messages: [],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      final sysInstr =
          capturedBody['systemInstruction'] as Map<String, dynamic>;
      final parts = sysInstr['parts'] as List<dynamic>;
      expect(
        parts.first,
        containsPair('text', 'You are a form designer.'),
      );
    });

    test('sends generationConfig with temperature and responseSchema', () async {
      late Map<String, dynamic> capturedBody;
      final schema = {
        'type': 'object',
        'properties': {
          'decision': {'type': 'string'},
        },
      };

      final client = _makeClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          _vertexResponse('{"ok":true}'),
          200,
        );
      });

      await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: schema,
            model: 'gemini-2.5-flash',
            temperature: 0.3,
          )
          .first;

      final genCfg = capturedBody['generationConfig'] as Map<String, dynamic>;
      expect(genCfg['temperature'], 0.3);
      expect(genCfg['responseMimeType'], 'application/json');
      expect(genCfg['responseSchema'], schema);
    });

    test('emits a single complete JSON string from stream', () async {
      final client = _makeClient(
        (request) async => http.Response(
          _vertexResponse('{"decision":"ask_step","engagement":"strong"}'),
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
      // Simulate two chunks, each with partial text that together form JSON.
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

      // Verify the concatenated text is valid JSON.
      expect(jsonDecode(result), {'hello': 1});
    });
  });

  group('VertexDirectClient — SSE streaming', () {
    /// Encodes [text] as a single Vertex SSE `data:` event line.
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

      final client = VertexDirectClient(
        apiKey: 'k',
        projectId: 'p',
        location: 'europe-west1',
        httpClient: mock,
      );
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
        '/v1/projects/p/locations/europe-west1/publishers/google/models/'
        'gemini-2.5-flash:streamGenerateContent',
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

      final client = VertexDirectClient(
        apiKey: 'k',
        projectId: 'p',
        location: 'europe-west1',
        httpClient: mock,
      );
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

      final client = VertexDirectClient(
        apiKey: 'k',
        projectId: 'p',
        location: 'europe-west1',
        httpClient: mock,
      );
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

  group('VertexDirectClient — error handling', () {
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

    test('HTTP 429 maps to RateLimitError', () async {
      final client = _makeClient(
        (request) async => http.Response(
          '{"error":"rate limit"}',
          429,
        ),
      );

      await expectLater(
        client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        emitsError(isA<RateLimitError>()),
      );
    });

    test('HTTP 429 parses Retry-After header in seconds', () async {
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

    test('HTTP 429 with no Retry-After header has null retryAfter', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"rate limit"}', 429),
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
            isNull,
          ),
        ),
      );
    });

    test('HTTP 500 maps to NetworkError', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"internal server error"}', 500),
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

    test('HTTP 503 maps to NetworkError', () async {
      final client = _makeClient(
        (request) async => http.Response('{"error":"unavailable"}', 503),
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

    test('malformed JSON response body maps to SchemaError', () async {
      // The Vertex response envelope is valid, but the inner text is not JSON.
      final client = _makeClient(
        (request) async => http.Response(
          _vertexResponse('not valid json {{{'),
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

    test('malformed Vertex envelope maps to SchemaError', () async {
      // The outer response body itself is not parseable as a Vertex array.
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

    test('exception from httpClient maps to NetworkError', () async {
      final client = VertexDirectClient(
        apiKey: 'key',
        projectId: 'proj',
        location: 'us-central1',
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
