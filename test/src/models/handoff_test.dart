import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/handoff.dart';

void main() {
  group('Handoff', () {
    test('is a typedef for void Function(dynamic)', () {
      var called = false;
      void handoffFn(dynamic result) {
        called = true;
        expect(result, 'test_result');
      }
      final Handoff h = handoffFn;
      h('test_result');
      expect(called, isTrue);
    });

    test('can be assigned a function matching the signature', () {
      void doNothing(dynamic _) {}
      final Handoff h = doNothing;
      expect(h, isA<Function>());
    });
  });

  group('EscalationHandler', () {
    test('is a typedef for void Function(dynamic)', () {
      var called = false;
      void handlerFn(dynamic result) {
        called = true;
      }
      final EscalationHandler handler = handlerFn;
      handler('any');
      expect(called, isTrue);
    });

    test('can be assigned a function matching the signature', () {
      void doNothing(dynamic _) {}
      final EscalationHandler handler = doNothing;
      expect(handler, isA<Function>());
    });
  });
}
