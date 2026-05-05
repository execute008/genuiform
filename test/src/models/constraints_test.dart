import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/constraints.dart';

void main() {
  group('NeverCollect', () {
    test('constructs with fieldOrTopic', () {
      const c = NeverCollect(fieldOrTopic: 'payment_info');
      expect(c.fieldOrTopic, 'payment_info');
    });

    test('JSON round-trip', () {
      const c = NeverCollect(fieldOrTopic: 'ssn');
      final json = c.toJson();
      expect(json['type'], 'NeverCollect');
      final restored = Constraint.fromJson(json);
      expect(restored, equals(c));
    });
  });

  group('NeverSkip', () {
    test('constructs with fieldIds', () {
      const c = NeverSkip(fieldIds: ['height_cm', 'weight_kg']);
      expect(c.fieldIds, ['height_cm', 'weight_kg']);
    });

    test('JSON round-trip', () {
      const c = NeverSkip(fieldIds: ['height_cm', 'weight_kg']);
      final json = c.toJson();
      expect(json['type'], 'NeverSkip');
      final restored = Constraint.fromJson(json);
      expect(restored, equals(c));
    });
  });

  group('MaxSteps', () {
    test('constructs with value', () {
      const c = MaxSteps(value: 15);
      expect(c.value, 15);
    });

    test('JSON round-trip', () {
      const c = MaxSteps(value: 8);
      final json = c.toJson();
      expect(json['type'], 'MaxSteps');
      final restored = Constraint.fromJson(json);
      expect(restored, equals(c));
    });
  });

  group('MinSteps', () {
    test('constructs with value', () {
      const c = MinSteps(value: 3);
      expect(c.value, 3);
    });

    test('JSON round-trip', () {
      const c = MinSteps(value: 3);
      final json = c.toJson();
      expect(json['type'], 'MinSteps');
      final restored = Constraint.fromJson(json);
      expect(restored, equals(c));
    });
  });

  group('WhitelistChoices', () {
    test('constructs', () {
      const c = WhitelistChoices(
        fieldId: 'role',
        allowed: ['decision_maker', 'influencer'],
      );
      expect(c.fieldId, 'role');
      expect(c.allowed, ['decision_maker', 'influencer']);
    });

    test('JSON round-trip', () {
      const c = WhitelistChoices(
        fieldId: 'role',
        allowed: ['a', 'b'],
      );
      final json = c.toJson();
      expect(json['type'], 'WhitelistChoices');
      final restored = Constraint.fromJson(json);
      expect(restored, equals(c));
    });
  });

  group('EscalateIf', () {
    test('constructs with trigger', () {
      final c = EscalateIf(
        trigger: 'eating disorder',
        handler: (_) {},
      );
      expect(c.trigger, 'eating disorder');
    });

    test('JSON serialises trigger but not handler', () {
      final c = EscalateIf(
        trigger: 'hostile language',
        handler: (_) {},
      );
      final json = c.toJson();
      expect(json['type'], 'EscalateIf');
      expect(json['trigger'], 'hostile language');
      // handler is not serialised — it is runtime-only
      expect(json.containsKey('handler'), isFalse);
    });

    test('fromJson restores trigger, handler is null', () {
      final json = <String, dynamic>{
        'type': 'EscalateIf',
        'trigger': 'legal threat',
      };
      final restored = Constraint.fromJson(json) as EscalateIf;
      expect(restored.trigger, 'legal threat');
      expect(restored.handler, isNull);
    });
  });

  group('StopIf', () {
    test('constructs with trigger', () {
      const c = StopIf(trigger: 'user is under 16');
      expect(c.trigger, 'user is under 16');
    });

    test('JSON round-trip', () {
      const c = StopIf(trigger: 'under age');
      final json = c.toJson();
      expect(json['type'], 'StopIf');
      final restored = Constraint.fromJson(json);
      expect(restored, equals(c));
    });
  });

  group('RequireConsent', () {
    test('constructs with topic', () {
      const c = RequireConsent(topic: 'health_data');
      expect(c.topic, 'health_data');
    });

    test('JSON round-trip', () {
      const c = RequireConsent(topic: 'health_data');
      final json = c.toJson();
      expect(json['type'], 'RequireConsent');
      final restored = Constraint.fromJson(json);
      expect(restored, equals(c));
    });
  });

  group('Constraint sealed family', () {
    test('all variants pattern-match', () {
      final constraints = <Constraint>[
        const NeverCollect(fieldOrTopic: 'x'),
        const NeverSkip(fieldIds: ['a']),
        const MaxSteps(value: 5),
        const MinSteps(value: 1),
        const WhitelistChoices(fieldId: 'f', allowed: ['v']),
        EscalateIf(trigger: 't', handler: null),
        const StopIf(trigger: 'u'),
        const RequireConsent(topic: 'c'),
      ];

      for (final c in constraints) {
        final label = switch (c) {
          NeverCollect() => 'NeverCollect',
          NeverSkip() => 'NeverSkip',
          MaxSteps() => 'MaxSteps',
          MinSteps() => 'MinSteps',
          WhitelistChoices() => 'WhitelistChoices',
          EscalateIf() => 'EscalateIf',
          StopIf() => 'StopIf',
          RequireConsent() => 'RequireConsent',
        };
        expect(label, isA<String>());
      }
    });
  });
}
