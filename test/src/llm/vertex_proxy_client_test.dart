// ignore_for_file: deprecated_member_use
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/llm/vertex_proxy_client.dart';
import 'package:genuiform/src/llm/llm_client.dart';
import 'package:genuiform/src/models/message.dart';

void main() {
  group('VertexProxyClient (stub)', () {
    test('compiles and is a LlmClient', () {
      final client = VertexProxyClient(
        endpoint: 'https://europe-west1-gymgeist.cloudfunctions.net/proxy',
        authProvider: () async => 'token',
      );
      expect(client, isA<LlmClient>());
    });

    test('generate throws UnimplementedError with deferral message', () {
      final client = VertexProxyClient(
        endpoint: 'https://example.com/proxy',
        authProvider: () async => null,
      );

      expect(
        () => client.generate(
          systemPrompt: 'sys',
          messages: [Message(role: MessageRole.user, content: 'hi')],
          responseSchema: {},
          model: 'gemini-2.5-flash',
        ),
        throwsA(
          isA<UnimplementedError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('VertexProxyClient'),
              contains('v0.1'),
            ),
          ),
        ),
      );
    });

    test('accepts an httpClient parameter', () {
      // Verifies the optional httpClient param exists and compiles.
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
