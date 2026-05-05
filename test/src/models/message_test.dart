import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/message.dart';

void main() {
  group('Message', () {
    test('constructs with role and content', () {
      const m = Message(role: MessageRole.user, content: 'Hello');
      expect(m.role, MessageRole.user);
      expect(m.content, 'Hello');
    });

    test('all roles exist', () {
      expect(MessageRole.values, containsAll([
        MessageRole.system,
        MessageRole.user,
        MessageRole.assistant,
      ]));
    });

    test('equality holds', () {
      const a = Message(role: MessageRole.assistant, content: 'Hi');
      const b = Message(role: MessageRole.assistant, content: 'Hi');
      expect(a, equals(b));
    });

    test('JSON round-trip: system message', () {
      const m = Message(role: MessageRole.system, content: 'You are a form.');
      final json = m.toJson();
      expect(json['role'], 'system');
      final restored = Message.fromJson(json);
      expect(restored, equals(m));
    });

    test('JSON round-trip: user message', () {
      const m = Message(role: MessageRole.user, content: 'My name is Alice.');
      final json = m.toJson();
      expect(json['role'], 'user');
      final restored = Message.fromJson(json);
      expect(restored, equals(m));
    });

    test('JSON round-trip: assistant message', () {
      const m = Message(role: MessageRole.assistant, content: 'What is your goal?');
      final json = m.toJson();
      expect(json['role'], 'assistant');
      final restored = Message.fromJson(json);
      expect(restored, equals(m));
    });
  });
}
