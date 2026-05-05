import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/llm/fake_llm_client.dart';
import 'package:genuiform/src/models/message.dart';

void main() {
  group('FakeLlmClient', () {
    test('replays scripted responses in order', () async {
      final client = FakeLlmClient(
        scriptedResponses: ['{"step":1}', '{"step":2}'],
      );

      final first = await client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hello')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;
      expect(first, '{"step":1}');

      final second = await client
          .generate(
            systemPrompt: 'sys',
            messages: [Message(role: MessageRole.user, content: 'hello')],
            responseSchema: {},
            model: 'gemini-2.5-flash',
          )
          .first;
      expect(second, '{"step":2}');
    });

    test('records invocations with all args', () async {
      final client = FakeLlmClient(
        scriptedResponses: ['{"ok":true}'],
      );

      await client
          .generate(
            systemPrompt: 'my system prompt',
            messages: [Message(role: MessageRole.user, content: 'test')],
            responseSchema: {'type': 'object'},
            model: 'gemini-3-flash',
            temperature: 0.5,
          )
          .first;

      expect(client.invocations, hasLength(1));
      final inv = client.invocations.first;
      expect(inv.systemPrompt, 'my system prompt');
      expect(inv.messages, hasLength(1));
      expect(inv.messages.first.role, MessageRole.user);
      expect(inv.messages.first.content, 'test');
      expect(inv.responseSchema, {'type': 'object'});
      expect(inv.model, 'gemini-3-flash');
      expect(inv.temperature, 0.5);
    });

    test('records multiple invocations', () async {
      final client = FakeLlmClient(
        scriptedResponses: ['{"a":1}', '{"b":2}'],
      );

      await client
          .generate(
            systemPrompt: 's1',
            messages: [],
            responseSchema: {},
            model: 'm',
          )
          .first;
      await client
          .generate(
            systemPrompt: 's2',
            messages: [],
            responseSchema: {},
            model: 'm',
          )
          .first;

      expect(client.invocations, hasLength(2));
      expect(client.invocations[0].systemPrompt, 's1');
      expect(client.invocations[1].systemPrompt, 's2');
    });

    test('throws StateError with informative message when exhausted', () async {
      final client = FakeLlmClient(
        scriptedResponses: ['{"once":true}'],
      );

      // First call succeeds.
      await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'm',
          )
          .first;

      // Second call should throw StateError.
      expect(
        () => client.generate(
          systemPrompt: 'sys',
          messages: [],
          responseSchema: {},
          model: 'm',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('FakeLlmClient'),
              contains('scripted responses exhausted'),
            ),
          ),
        ),
      );
    });

    test('respects responseDelay', () async {
      final client = FakeLlmClient(
        scriptedResponses: ['{"delayed":true}'],
        responseDelay: const Duration(milliseconds: 50),
      );

      final stopwatch = Stopwatch()..start();
      await client
          .generate(
            systemPrompt: 'sys',
            messages: [],
            responseSchema: {},
            model: 'm',
          )
          .first;
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(50));
    });

    test('invocations is empty before any generate call', () {
      final client = FakeLlmClient(scriptedResponses: ['{}']);
      expect(client.invocations, isEmpty);
    });

    test('generate returns a Stream<String>', () {
      final client = FakeLlmClient(scriptedResponses: ['{"x":1}']);
      final stream = client.generate(
        systemPrompt: 'sys',
        messages: [],
        responseSchema: {},
        model: 'm',
      );
      expect(stream, isA<Stream<String>>());
    });
  });
}
