// Pure Dart unit tests — no Flutter / pumpWidget.
// ignore_for_file: avoid_dynamic_calls

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

void main() {
  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Builds a step with choices so WhitelistChoices tests can work.
  QuizStepSpec choiceStep({
    String id = 'field_x',
    required List<QuizChoice> choices,
  }) =>
      QuizStepSpec(
        id: id,
        title: 'Pick one',
        inputType: QuizInputType.choice,
        choices: choices,
      );

  QuizChoice choice(String id) => QuizChoice(id: id, label: id);

  // ── NeverCollect ──────────────────────────────────────────────────────────

  group('NeverCollect', () {
    test('blocks step whose id matches (case-insensitive)', () {
      final enforcer = ConstraintEnforcer([
        NeverCollect(fieldOrTopic: 'payment_info'),
      ]);
      final step = sampleStep(id: 'PAYMENT_INFO');
      final session = sampleSession();
      final result = enforcer.check(step, session);
      expect(result, isA<Replaced>());
    });

    test('blocks step whose title contains the topic (case-insensitive)', () {
      final enforcer = ConstraintEnforcer([
        NeverCollect(fieldOrTopic: 'ssn'),
      ]);
      final step = sampleStep(id: 'identity', title: 'Please enter your SSN');
      final result = enforcer.check(step, sampleSession());
      expect(result, isA<Replaced>());
    });

    test('blocks step whose description contains the topic', () {
      final enforcer = ConstraintEnforcer([
        NeverCollect(fieldOrTopic: 'credit card'),
      ]);
      final step = sampleStep(
        id: 'billing',
        title: 'Billing info',
        description: 'Enter your credit card number',
      );
      final result = enforcer.check(step, sampleSession());
      expect(result, isA<Replaced>());
    });

    test('Replaced step is noneJustInformation type', () {
      final enforcer = ConstraintEnforcer([
        NeverCollect(fieldOrTopic: 'payment_info'),
      ]);
      final step = sampleStep(id: 'payment_info');
      final result = enforcer.check(step, sampleSession()) as Replaced;
      expect(result.replacement.inputType, QuizInputType.noneJustInformation);
    });

    test('allows unrelated step', () {
      final enforcer = ConstraintEnforcer([
        NeverCollect(fieldOrTopic: 'payment_info'),
      ]);
      final step = sampleStep(id: 'name', title: 'What is your name?');
      final result = enforcer.check(step, sampleSession());
      expect(result, isA<Allowed>());
    });
  });

  // ── MaxSteps ──────────────────────────────────────────────────────────────

  group('MaxSteps', () {
    test('returns Stop when history.length >= max', () {
      final enforcer = ConstraintEnforcer([MaxSteps(value: 3)]);
      final session = sampleSession(
        history: [
          sampleAnswer(stepId: 'a'),
          sampleAnswer(stepId: 'b'),
          sampleAnswer(stepId: 'c'),
        ],
      );
      final result = enforcer.check(sampleStep(), session);
      expect(result, isA<Stop>());
      expect((result as Stop).reason, contains('3'));
    });

    test('allows when history.length < max', () {
      final enforcer = ConstraintEnforcer([MaxSteps(value: 3)]);
      final session = sampleSession(
        history: [
          sampleAnswer(stepId: 'a'),
          sampleAnswer(stepId: 'b'),
        ],
      );
      final result = enforcer.check(sampleStep(), session);
      expect(result, isA<Allowed>());
    });

    test('stop reason includes the limit value', () {
      final enforcer = ConstraintEnforcer([MaxSteps(value: 5)]);
      final session = sampleSession(
        history: List.generate(5, (i) => sampleAnswer(stepId: 'step_$i')),
      );
      final result = enforcer.check(sampleStep(), session) as Stop;
      expect(result.reason, contains('5'));
    });
  });

  // ── MinSteps ──────────────────────────────────────────────────────────────

  group('MinSteps', () {
    test('isAboveMinimum returns false when below minimum', () {
      final enforcer = ConstraintEnforcer([MinSteps(value: 3)]);
      final session = sampleSession(
        history: [sampleAnswer(stepId: 'a')],
      );
      expect(enforcer.isAboveMinimum(session), isFalse);
    });

    test('isAboveMinimum returns true when at minimum', () {
      final enforcer = ConstraintEnforcer([MinSteps(value: 2)]);
      final session = sampleSession(
        history: [
          sampleAnswer(stepId: 'a'),
          sampleAnswer(stepId: 'b'),
        ],
      );
      expect(enforcer.isAboveMinimum(session), isTrue);
    });

    test('isAboveMinimum returns true when above minimum', () {
      final enforcer = ConstraintEnforcer([MinSteps(value: 2)]);
      final session = sampleSession(
        history: List.generate(5, (i) => sampleAnswer(stepId: 'step_$i')),
      );
      expect(enforcer.isAboveMinimum(session), isTrue);
    });

    test('check always returns Allowed (MinSteps does not block steps)', () {
      final enforcer = ConstraintEnforcer([MinSteps(value: 10)]);
      final session = sampleSession();
      final result = enforcer.check(sampleStep(), session);
      expect(result, isA<Allowed>());
    });

    test('when no MinSteps constraint, isAboveMinimum returns true', () {
      final enforcer = ConstraintEnforcer([MaxSteps(value: 10)]);
      final session = sampleSession();
      expect(enforcer.isAboveMinimum(session), isTrue);
    });
  });

  // ── NeverSkip ─────────────────────────────────────────────────────────────

  group('NeverSkip', () {
    test('canComplete returns false when listed field is missing', () {
      final enforcer = ConstraintEnforcer([
        NeverSkip(fieldIds: ['height_cm', 'weight_kg']),
      ]);
      final session = sampleSession(answers: {'height_cm': 180});
      expect(enforcer.canComplete(session), isFalse);
    });

    test('canComplete returns true when all listed fields are present', () {
      final enforcer = ConstraintEnforcer([
        NeverSkip(fieldIds: ['height_cm', 'weight_kg']),
      ]);
      final session = sampleSession(
        answers: {'height_cm': 180, 'weight_kg': 75},
      );
      expect(enforcer.canComplete(session), isTrue);
    });

    test('check returns Allowed (NeverSkip does not block individual steps)',
        () {
      final enforcer = ConstraintEnforcer([
        NeverSkip(fieldIds: ['height_cm']),
      ]);
      final result = enforcer.check(sampleStep(), sampleSession());
      expect(result, isA<Allowed>());
    });

    test('canComplete returns false when field value is explicitly null', () {
      final enforcer = ConstraintEnforcer([
        NeverSkip(fieldIds: ['height_cm']),
      ]);
      final session = sampleSession(answers: {'height_cm': null});
      expect(enforcer.canComplete(session), isFalse);
    });
  });

  // ── WhitelistChoices ──────────────────────────────────────────────────────

  group('WhitelistChoices', () {
    test('filters out disallowed choices for matching fieldId', () {
      final enforcer = ConstraintEnforcer([
        WhitelistChoices(fieldId: 'timeline', allowed: ['immediate', '1-3m']),
      ]);
      final step = choiceStep(
        id: 'timeline',
        choices: [
          choice('immediate'),
          choice('1-3m'),
          choice('6+'),
        ],
      );
      final result = enforcer.check(step, sampleSession());
      expect(result, isA<Replaced>());
      final replaced = result as Replaced;
      final ids = replaced.replacement.choices!.map((c) => c.id).toList();
      expect(ids, containsAll(['immediate', '1-3m']));
      expect(ids, isNot(contains('6+')));
    });

    test('returns Allowed when all choices are whitelisted', () {
      final enforcer = ConstraintEnforcer([
        WhitelistChoices(fieldId: 'timeline', allowed: ['a', 'b', 'c']),
      ]);
      final step = choiceStep(
        id: 'timeline',
        choices: [choice('a'), choice('b')],
      );
      final result = enforcer.check(step, sampleSession());
      expect(result, isA<Allowed>());
    });

    test('returns Allowed for different fieldId', () {
      final enforcer = ConstraintEnforcer([
        WhitelistChoices(fieldId: 'timeline', allowed: ['a']),
      ]);
      final step = choiceStep(
        id: 'other_field',
        choices: [choice('x'), choice('y')],
      );
      final result = enforcer.check(step, sampleSession());
      expect(result, isA<Allowed>());
    });

    test('returns Allowed when step has no choices (non-choice inputType)', () {
      final enforcer = ConstraintEnforcer([
        WhitelistChoices(fieldId: 'field_x', allowed: ['a']),
      ]);
      final step = sampleStep(id: 'field_x', inputType: QuizInputType.text);
      final result = enforcer.check(step, sampleSession());
      expect(result, isA<Allowed>());
    });
  });

  // ── EscalateIf ────────────────────────────────────────────────────────────

  group('EscalateIf', () {
    test('fires Escalated when answer contains trigger (case-insensitive)', () {
      bool handlerCalled = false;
      final rule = EscalateIf(
        trigger: 'eating disorder',
        handler: (_) => handlerCalled = true,
      );
      final enforcer = ConstraintEnforcer([rule]);
      final answer = sampleAnswer(
        answer: 'I have struggled with an Eating Disorder for years',
      );
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Escalated>());
      expect((result as Escalated).rule, rule);
      // Handler invocation is caller's responsibility per spec — not tested here
      expect(handlerCalled, isFalse); // handler NOT called by enforcer itself
    });

    test('returns Allowed when answer does not match trigger', () {
      final rule = EscalateIf(
        trigger: 'eating disorder',
        handler: (_) {},
      );
      final enforcer = ConstraintEnforcer([rule]);
      final answer = sampleAnswer(answer: 'I want to lose weight');
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Allowed>());
    });

    test('non-String answer returns Allowed (cannot match trigger)', () {
      final rule = EscalateIf(
        trigger: 'eating disorder',
        handler: (_) {},
      );
      final enforcer = ConstraintEnforcer([rule]);
      final answer = sampleAnswer(answer: 42);
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Allowed>());
    });
  });

  // ── StopIf ────────────────────────────────────────────────────────────────

  group('StopIf', () {
    test('returns Stop when answer matches trigger', () {
      final enforcer = ConstraintEnforcer([
        StopIf(trigger: 'under 16'),
      ]);
      final answer = sampleAnswer(answer: 'I am under 16 years old');
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Stop>());
    });

    test('Stop reason equals the trigger string', () {
      final enforcer = ConstraintEnforcer([
        StopIf(trigger: 'under 16'),
      ]);
      final answer = sampleAnswer(answer: 'under 16');
      final result = enforcer.inspectAnswer(answer, sampleSession()) as Stop;
      expect(result.reason, 'under 16');
    });

    test('returns Allowed when answer does not match', () {
      final enforcer = ConstraintEnforcer([
        StopIf(trigger: 'under 16'),
      ]);
      final answer = sampleAnswer(answer: 'I am 25 years old');
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Allowed>());
    });

    test('case-insensitive: STOP TRIGGER matches lower-case trigger', () {
      final enforcer = ConstraintEnforcer([
        StopIf(trigger: 'hostile language'),
      ]);
      final answer = sampleAnswer(answer: 'Using HOSTILE LANGUAGE here');
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Stop>());
    });

    test('reproduction: StopIf fails to catch trigger in List answer (multiChoice)', () {
      final enforcer = ConstraintEnforcer([
        StopIf(trigger: 'under 16'),
      ]);
      // Currently, _matchAnswerText returns false if answer is not a String
      final answer = sampleAnswer(answer: ['option1', 'under 16']);
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Stop>(), reason: 'Should catch trigger in List answer');
    });

    test('reproduction: StopIf fails to catch trigger in choice label but not ID', () {
      final enforcer = ConstraintEnforcer([
        StopIf(trigger: 'under 16'),
      ]);

      final step = choiceStep(
        id: 'age_group',
        choices: [
          const QuizChoice(id: 'group_a', label: 'I am under 16 years old'),
          const QuizChoice(id: 'group_b', label: 'I am 16 or older'),
        ],
      );

      // Answer is the choice ID 'group_a'
      final answer = sampleAnswer(
        stepId: 'age_group',
        stepSpec: step,
        answer: 'group_a',
      );

      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Stop>(), reason: 'Should catch trigger in choice label');
    });
  });

  // ── RequireConsent ────────────────────────────────────────────────────────

  group('RequireConsent', () {
    test('returns Replaced with consent step when topic not in __consents', () {
      final enforcer = ConstraintEnforcer([
        RequireConsent(topic: 'health_data'),
      ]);
      // No __consents key in answers
      final session = sampleSession(answers: {});
      final result = enforcer.check(sampleStep(id: 'bmi'), session);
      expect(result, isA<Replaced>());
      final replaced = result as Replaced;
      expect(replaced.replacement.inputType, QuizInputType.noneJustInformation);
    });

    test('returns Allowed once topic is in __consents list', () {
      final enforcer = ConstraintEnforcer([
        RequireConsent(topic: 'health_data'),
      ]);
      final session = sampleSession(
        answers: {'__consents': <String>['health_data', 'marketing']},
      );
      final result = enforcer.check(sampleStep(id: 'bmi'), session);
      expect(result, isA<Allowed>());
    });

    test('Replaced when topic absent from non-empty __consents list', () {
      final enforcer = ConstraintEnforcer([
        RequireConsent(topic: 'health_data'),
      ]);
      final session = sampleSession(
        answers: {'__consents': <String>['marketing']},
      );
      final result = enforcer.check(sampleStep(id: 'bmi'), session);
      expect(result, isA<Replaced>());
    });
  });

  // ── Constraint ordering / short-circuit ──────────────────────────────────

  group('Constraint ordering', () {
    test('short-circuits on first non-Allowed result', () {
      // MaxSteps fires first (history length = 5, max = 5)
      // NeverCollect would also fire — but we never reach it
      final enforcer = ConstraintEnforcer([
        MaxSteps(value: 5),
        NeverCollect(fieldOrTopic: 'xyz'),
      ]);
      final session = sampleSession(
        history: List.generate(5, (i) => sampleAnswer(stepId: 'step_$i')),
      );

      final step = sampleStep(id: 'xyz', title: 'xyz question');
      final result = enforcer.check(step, session);
      expect(result, isA<Stop>()); // MaxSteps fired
    });

    test('inspectAnswer short-circuits on first non-Allowed result', () {
      final enforcer = ConstraintEnforcer([
        EscalateIf(trigger: 'eating disorder', handler: (_) {}),
        StopIf(trigger: 'under 16'),
      ]);
      // Both triggers appear, but EscalateIf is first
      final answer = sampleAnswer(answer: 'eating disorder and under 16');
      final result = enforcer.inspectAnswer(answer, sampleSession());
      expect(result, isA<Escalated>());
    });
  });

  // ── Multi-constraint combination ──────────────────────────────────────────

  group('Multiple constraints', () {
    test('Allowed when no constraint fires', () {
      final enforcer = ConstraintEnforcer([
        NeverCollect(fieldOrTopic: 'payment_info'),
        MaxSteps(value: 10),
        NeverSkip(fieldIds: ['height_cm']),
      ]);
      final session = sampleSession(answers: {'height_cm': 180});
      final result = enforcer.check(sampleStep(id: 'name'), session);
      expect(result, isA<Allowed>());
    });
  });
}
