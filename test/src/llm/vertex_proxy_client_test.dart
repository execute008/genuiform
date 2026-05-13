import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:genuiform/src/llm/llm_client.dart';
import 'package:genuiform/src/llm/vertex_proxy_client.dart';
import 'package:genuiform/src/models/message.dart';

const _validVertexResponse = '''
[
  {
    "candidates": [
      {
        "content": {
          "parts": [
            {"text": "{\\"decision\\":\\"complete\\",\\"engagement\\":\\"strong\\"}"}
          ]
        }
      }
    ]
  }
]
''';

void main() {
  group('VertexProxyClient', () {
    test('is an LlmClient', () {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => 'token',
      );
      expect(client, isA<LlmClient>());
    });

    test('throws AuthError when authProvider returns null', () async {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => null,
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await expectLater(
        client
            .generate(
              systemPrompt: 'sys',
              messages: [Message(role: MessageRole.user, content: 'hi')],
              responseSchema: {},
              model: 'gemini-2.5-flash',
            )
            .first,
        throwsA(isA<AuthError>()),
      );
    });

    test('throws AuthError when authProvider returns empty string', () async {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => '',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      await expectLater(
        client
            .generate(
              systemPrompt: 'sys',
              messages: [Message(role: MessageRole.user, content: 'hi')],
              responseSchema: {},
              model: 'gemini-2.5-flash',
            )
            .first,
        throwsA(isA<AuthError>()),
      );
    });

    test('happy path: posts JSON payload with bearer auth, returns full text',
        () async {
      late http.Request capturedRequest;

      final client = VertexProxyClient(
        endpoint: 'https://eu-west1-test.cloudfunctions.net/proxy',
        authProvider: () async => 'firebase-id-token-abc',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            _validVertexResponse,
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await client
          .generate(
            systemPrompt: 'You are a form designer.',
            messages: [
              Message(role: MessageRole.user, content: 'Start the form.'),
            ],
            responseSchema: {'type': 'object'},
            model: 'gemini-2.5-flash',
            temperature: 0.5,
          )
          .first;

      expect(
        result,
        '{"decision":"complete","engagement":"strong"}',
      );
      expect(
        capturedRequest.url.toString(),
        'https://eu-west1-test.cloudfunctions.net/proxy',
      );
      expect(capturedRequest.headers['Authorization'],
          'Bearer firebase-id-token-abc');
      expect(capturedRequest.headers['Content-Type'], 'application/json');

      // Verify the JSON payload shape.
      final body = capturedRequest.body;
      expect(body, contains('"systemPrompt":"You are a form designer."'));
      expect(body, contains('"model":"gemini-2.5-flash"'));
      expect(body, contains('"temperature":0.5'));
      expect(body, contains('"messages"'));
      expect(body, contains('"responseSchema"'));
    });

    test('maps HTTP 401 to AuthError and sanitizes', () async {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => 'token',
        httpClient:
            MockClient((_) async => http.Response('Unauthorized-secret-leak', 401)),
      );

      final call = client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      await expectLater(
        call,
        throwsA(isA<AuthError>().having(
          (e) => e.message,
          'message',
          isNot(contains('Unauthorized-secret-leak')),
        )),
      );
    });

    test('maps HTTP 429 to RateLimitError with retry-after parsed', () async {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => 'token',
        httpClient: MockClient(
          (_) async => http.Response(
            'rate limited',
            429,
            headers: {'retry-after': '30'},
          ),
        ),
      );

      try {
        await client
            .generate(
              systemPrompt: 'sys',
              messages: [Message(role: MessageRole.user, content: 'hi')],
              responseSchema: {},
              model: 'gemini-2.5-flash',
            )
            .first;
        fail('expected RateLimitError');
      } on RateLimitError catch (e) {
        expect(e.retryAfter, const Duration(seconds: 30));
      }
    });

    test('maps HTTP 5xx to NetworkError and sanitizes', () async {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => 'token',
        httpClient: MockClient(
          (_) async => http.Response('Internal-Server-Error-secret-leak', 502),
        ),
      );

      final call = client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      await expectLater(
        call,
        throwsA(isA<NetworkError>().having(
          (e) => e.message,
          'message',
          isNot(contains('Internal-Server-Error-secret-leak')),
        )),
      );
    });

    test('malformed JSON envelope raises SchemaError and sanitizes', () async {
      const malformedBody = 'not-json-at-all-secret-leak';
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => 'token',
        httpClient: MockClient(
          (_) async => http.Response(malformedBody, 200),
        ),
      );

      final call = client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hi')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;

      await expectLater(
        call,
        throwsA(isA<SchemaError>().having(
          (e) => e.message,
          'message',
          isNot(contains(malformedBody)),
        )),
      );
    });

    test('accumulated text that is not valid JSON raises SchemaError',
        () async {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => 'token',
        httpClient: MockClient(
          (_) async => http.Response(
            '''[{"candidates":[{"content":{"parts":[{"text":"not-json-output"}]}}]}]''',
            200,
          ),
        ),
      );

      await expectLater(
        client
            .generate(
              systemPrompt: 'sys',
              messages: [Message(role: MessageRole.user, content: 'hi')],
              responseSchema: {},
              model: 'gemini-2.5-flash',
            )
            .first,
        throwsA(isA<SchemaError>()),
      );
    });

    test('accepts httpClient: null and constructs a default', () {
      expect(
        () => VertexProxyClient(
          endpoint: 'https://example.com/proxy',
          authProvider: () async => 'token',
          httpClient: null,
        ),
        returnsNormally,
      );
    });
  });
}
