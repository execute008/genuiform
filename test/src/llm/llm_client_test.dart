import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/llm/llm_client.dart';
import 'package:genuiform/src/models/message.dart';

/// A minimal concrete implementation used only in this test file to verify that
/// [LlmClient] can be subclassed and that [generate] returns a [Stream<String>].
class _TestLlmClient extends LlmClient {
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
    return Stream.value('{"ok":true}');
  }

  @override
  Future<String> createCachedContent({
    required String systemInstruction,
    required String model,
    Duration ttl = const Duration(seconds: 300),
  }) async => 'cachedContents/fake';

  @override
  Future<void> deleteCachedContent(String name) async {}
}

void main() {
  group('LlmClient', () {
    test('can be subclassed and generate returns Stream<String>', () async {
      final client = _TestLlmClient();
      final result = await client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hello')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;
      expect(result, '{"ok":true}');
    });

    test('Message has role and content', () {
      const msg = Message(role: MessageRole.user, content: 'hi');
      expect(msg.role, MessageRole.user);
      expect(msg.content, 'hi');
    });

    test('Message.toJson serialises role via wireValue', () {
      const msg = Message(role: MessageRole.assistant, content: 'hello');
      expect(msg.toJson(), {'role': 'assistant', 'content': 'hello'});
    });
  });

  group('LlmClientError sealed family', () {
    test('NetworkError implements Exception with message', () {
      const err = NetworkError('socket closed');
      expect(err, isA<LlmClientError>());
      expect(err, isA<Exception>());
      expect(err.message, 'socket closed');
    });

    test('AuthError implements LlmClientError', () {
      const err = AuthError('401 Unauthorized');
      expect(err, isA<LlmClientError>());
      expect(err.message, '401 Unauthorized');
    });

    test('RateLimitError carries retryAfter', () {
      const err = RateLimitError(
        '429 Too Many Requests',
        retryAfter: Duration(seconds: 30),
      );
      expect(err, isA<LlmClientError>());
      expect(err.retryAfter, const Duration(seconds: 30));
    });

    test('RateLimitError retryAfter may be null', () {
      const err = RateLimitError('429 Too Many Requests');
      expect(err.retryAfter, isNull);
    });

    test('SchemaError implements LlmClientError', () {
      const err = SchemaError('JSON parse failed');
      expect(err, isA<LlmClientError>());
    });

    test('CacheError implements LlmClientError', () {
      const err = CacheError('cache expired');
      expect(err, isA<LlmClientError>());
      expect(err.message, 'cache expired');
    });

    test('UnknownError carries cause', () {
      final cause = Exception('boom');
      final err = UnknownError('unexpected', cause: cause);
      expect(err.cause, cause);
    });

    test('toString includes runtime type and message', () {
      const err = AuthError('forbidden');
      expect(err.toString(), contains('AuthError'));
      expect(err.toString(), contains('forbidden'));
    });
  });
}
