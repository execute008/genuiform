import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/constraints.dart';
import 'package:genuiform/src/models/contract.dart';
import 'package:genuiform/src/models/field_spec.dart';
import 'package:genuiform/src/models/form_result.dart';
import 'package:genuiform/src/models/outcomes.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/models/session_status.dart';
import 'package:genuiform/src/models/step_event.dart';

void main() {
  const emailField = FieldSpec(type: 'String', required: true);
  final accountContract = Contract(fields: {'email': emailField});
  final outcome = Outcome(
    id: 'result',
    contractDelta: accountContract,
    handoff: (_) {},
  );
  final formResult = FormResult(
    collectedFields: const {'email': 'alice@example.com'},
    reachedOutcome: outcome,
    history: const [],
    status: SessionStatus.completed,
  );
  final spec = QuizStepSpec(
    id: 'step_name',
    title: 'Your name?',
    inputType: QuizInputType.text,
  );
  final layer = Layer(
    id: 'account_only',
    contractDelta: accountContract,
    handoff: (_) {},
  );

  group('StepEvent sealed family', () {
    test('StepReady carries QuizStepSpec', () {
      final event = StepReady(spec: spec);
      expect(event.spec.id, 'step_name');
    });

    test('LayerComplete carries layer and offerExit', () {
      final event = LayerComplete(layer: layer, offerExit: true);
      expect(event.layer.id, 'account_only');
      expect(event.offerExit, isTrue);
    });

    test('BranchTaken carries branchId and optionId', () {
      const event = BranchTaken(branchId: 'nutrition_path', optionId: 'with_meal_plan');
      expect(event.branchId, 'nutrition_path');
      expect(event.optionId, 'with_meal_plan');
    });

    test('OutcomeReached carries outcome and result', () {
      final event = OutcomeReached(outcome: outcome, result: formResult);
      expect(event.outcome.id, 'result');
      expect(event.result.status, SessionStatus.completed);
    });

    test('EscalationFired carries EscalateIf rule', () {
      final rule = EscalateIf(trigger: 'eating disorder', handler: null);
      final event = EscalationFired(rule: rule);
      expect(event.rule.trigger, 'eating disorder');
    });

    test('StreamError carries error object', () {
      final error = Exception('connection lost');
      final event = StreamError(error: error);
      expect(event.error, isA<Exception>());
    });

    test('all variants are StepEvent', () {
      final events = <StepEvent>[
        StepReady(spec: spec),
        LayerComplete(layer: layer, offerExit: false),
        const BranchTaken(branchId: 'b', optionId: 'o'),
        OutcomeReached(outcome: outcome, result: formResult),
        EscalationFired(rule: EscalateIf(trigger: 't', handler: null)),
        StreamError(error: 'err'),
      ];
      for (final e in events) {
        expect(e, isA<StepEvent>());
      }
    });

    test('pattern matching works on all variants', () {
      final events = <StepEvent>[
        StepReady(spec: spec),
        LayerComplete(layer: layer, offerExit: false),
        const BranchTaken(branchId: 'b', optionId: 'o'),
        OutcomeReached(outcome: outcome, result: formResult),
        EscalationFired(rule: EscalateIf(trigger: 't', handler: null)),
        StreamError(error: 'err'),
      ];

      for (final event in events) {
        final label = switch (event) {
          StepReady() => 'StepReady',
          LayerComplete() => 'LayerComplete',
          BranchTaken() => 'BranchTaken',
          OutcomeReached() => 'OutcomeReached',
          EscalationFired() => 'EscalationFired',
          StreamError() => 'StreamError',
        };
        expect(label, isA<String>());
      }
    });
  });
}
