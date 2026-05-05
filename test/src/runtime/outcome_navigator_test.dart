// Pure Dart unit tests — no Flutter / pumpWidget.

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

void main() {
  // ── Single Outcome tree ───────────────────────────────────────────────────

  group('single Outcome', () {
    late Outcome outcome;
    late OutcomeNavigator navigator;

    setUp(() {
      outcome = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {
          'name': const FieldSpec(type: 'String', required: true),
          'email': const FieldSpec(type: 'String', required: true),
        }),
        handoff: null,
      );
      navigator = OutcomeNavigator(outcome);
    });

    test('advance returns null (terminal node)', () {
      final session = sampleSession(currentNode: outcome);
      expect(navigator.advance(session), isNull);
    });

    test('isComplete returns true when all required fields answered', () {
      // runningContract must reflect the outcome's delta for isComplete to work
      final sessionWithContract = Session(
        currentNode: outcome,
        history: const [],
        answers: {'name': 'Alice', 'email': 'alice@example.com'},
        runningContract: outcome.contractDelta,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      expect(navigator.isComplete(sessionWithContract), isTrue);
    });

    test('isComplete returns false when required fields missing', () {
      final session = Session(
        currentNode: outcome,
        history: const [],
        answers: {'name': 'Alice'}, // email missing
        runningContract: outcome.contractDelta,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      expect(navigator.isComplete(session), isFalse);
    });

    test('isComplete returns false when currentNode is not an Outcome', () {
      final layer = Layer(
        id: 'my_layer',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      final session = Session(
        currentNode: layer,
        history: const [],
        answers: {},
        runningContract: Contract(fields: {}),
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      final nav = OutcomeNavigator(layer);
      expect(nav.isComplete(session), isFalse);
    });
  });

  // ── Three-Layer ladder ────────────────────────────────────────────────────

  group('three-Layer ladder', () {
    late Layer layerA;
    late Layer layerB;
    late Layer layerC;
    late OutcomeNavigator navigator;

    setUp(() {
      layerC = Layer(
        id: 'layer_c',
        contractDelta: Contract(fields: {
          'c_field': const FieldSpec(type: 'String', required: true),
        }),
        handoff: null,
      );
      layerB = Layer(
        id: 'layer_b',
        contractDelta: Contract(fields: {
          'b_field': const FieldSpec(type: 'String', required: true),
        }),
        handoff: null,
        next: layerC,
      );
      layerA = Layer(
        id: 'layer_a',
        contractDelta: Contract(fields: {
          'a_field': const FieldSpec(type: 'String', required: true),
        }),
        handoff: null,
        next: layerB,
      );
      navigator = OutcomeNavigator(layerA);
    });

    test('advance from layerA returns layerB', () {
      final session = sampleSession(currentNode: layerA);
      expect(navigator.advance(session)?.id, 'layer_b');
    });

    test('advance from layerB returns layerC', () {
      final session = sampleSession(currentNode: layerB);
      expect(navigator.advance(session)?.id, 'layer_c');
    });

    test('advance from layerC (no next) returns null', () {
      final session = sampleSession(currentNode: layerC);
      expect(navigator.advance(session), isNull);
    });

    test('isLayerComplete returns false when fields missing', () {
      final session = sampleSession(
        currentNode: layerA,
        answers: {},
      );
      expect(navigator.isLayerComplete(layerA, session), isFalse);
    });

    test('isLayerComplete returns true when all fields up to and including layer filled', () {
      final session = sampleSession(
        currentNode: layerA,
        answers: {'a_field': 'value_a'},
      );
      expect(navigator.isLayerComplete(layerA, session), isTrue);
    });

    test('isLayerComplete for layerB requires a_field AND b_field', () {
      final sessionMissingB = sampleSession(
        currentNode: layerB,
        answers: {'a_field': 'value_a'},
      );
      // b_field is required by layerB's contractDelta
      // isLayerComplete checks cumulative contract up to layerB
      expect(navigator.isLayerComplete(layerB, sessionMissingB), isFalse);

      final sessionComplete = sampleSession(
        currentNode: layerB,
        answers: {'a_field': 'value_a', 'b_field': 'value_b'},
      );
      expect(navigator.isLayerComplete(layerB, sessionComplete), isTrue);
    });
  });

  // ── Branch resolution ─────────────────────────────────────────────────────

  group('Branch resolution', () {
    late Branch branch;
    late Outcome outcomeA;
    late Outcome outcomeB;
    late OutcomeNavigator navigator;

    setUp(() {
      outcomeA = Outcome(
        id: 'outcome_a',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      outcomeB = Outcome(
        id: 'outcome_b',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      branch = Branch(
        id: 'my_branch',
        options: [
          BranchOption(
            id: 'opt_a',
            criterion: 'criterion a',
            contractDelta: null,
            child: outcomeA,
          ),
          BranchOption(
            id: 'opt_b',
            criterion: 'criterion b',
            contractDelta: null,
            child: outcomeB,
          ),
        ],
      );
      navigator = OutcomeNavigator(branch);
    });

    test('advance with chosenBranchOption returns matching child', () {
      final session = sampleSession(currentNode: branch);
      final next = navigator.advance(session, chosenBranchOption: 'opt_a');
      expect(next?.id, 'outcome_a');
    });

    test('advance to opt_b returns outcomeB', () {
      final session = sampleSession(currentNode: branch);
      final next = navigator.advance(session, chosenBranchOption: 'opt_b');
      expect(next?.id, 'outcome_b');
    });

    test('advance without chosenBranchOption throws StateError', () {
      final session = sampleSession(currentNode: branch);
      expect(
        () => navigator.advance(session),
        throwsA(isA<StateError>()),
      );
    });

    test('advance with unknown option id throws StateError', () {
      final session = sampleSession(currentNode: branch);
      expect(
        () => navigator.advance(session, chosenBranchOption: 'nonexistent'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('nonexistent'),
        )),
      );
    });
  });

  // ── GymGeist tree (full ladder + branch with nullable contractDelta) ───────

  group('GymGeist tree', () {
    late OutcomeNode root;
    late OutcomeNavigator navigator;

    setUp(() {
      root = gymgeistTree();
      navigator = OutcomeNavigator(root);
    });

    test('root is account_only Layer', () {
      expect(root.id, 'account_only');
    });

    test('advance from account_only returns with_workout_plan', () {
      final session = sampleSession(currentNode: root);
      final next = navigator.advance(session);
      expect(next?.id, 'with_workout_plan');
    });

    test('advance from with_workout_plan returns nutrition_path branch', () {
      final withWorkout = (root as Layer).next!;
      final session = sampleSession(currentNode: withWorkout);
      final next = navigator.advance(session);
      expect(next?.id, 'nutrition_path');
    });

    test('advance from nutrition_path branch with skip_nutrition returns workout_only', () {
      final withWorkout = (root as Layer).next!;
      final nutritionBranch = (withWorkout as Layer).next!;
      final session = sampleSession(currentNode: nutritionBranch);
      final next = navigator.advance(
        session,
        chosenBranchOption: 'skip_nutrition',
      );
      expect(next?.id, 'workout_only');
    });

    test('advance from nutrition_path with with_meal_plan returns full_meal_plan', () {
      final withWorkout = (root as Layer).next!;
      final nutritionBranch = (withWorkout as Layer).next!;
      final session = sampleSession(currentNode: nutritionBranch);
      final next = navigator.advance(
        session,
        chosenBranchOption: 'with_meal_plan',
      );
      expect(next?.id, 'full_meal_plan');
    });

    test('advance from workout_only Outcome returns null', () {
      final withWorkout = (root as Layer).next!;
      final nutritionBranch = (withWorkout as Layer).next! as Branch;
      final skipOption = nutritionBranch.options
          .firstWhere((o) => o.id == 'skip_nutrition');
      final workoutOnly = skipOption.child;
      final session = sampleSession(currentNode: workoutOnly);
      expect(navigator.advance(session), isNull);
    });

    test('runningContract uses chosenBranchOptions from session answers', () {
      // When __branch_choices is set in answers, the navigator should read it
      final withWorkout = (root as Layer).next!;
      final nutritionBranch = (withWorkout as Layer).next!;
      final session = Session(
        currentNode: nutritionBranch,
        history: const [],
        answers: {
          'email': 'alice@example.com',
          'name': 'Alice',
          '__branch_choices': {'nutrition_path': 'with_meal_plan'},
        },
        runningContract: Contract(fields: {}),
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      final contract = navigator.runningContract(session);
      // Should include account fields, workout fields, and meal plan fields
      expect(contract.fields.containsKey('dietary_restrictions'), isTrue);
    });
  });

  // ── runningContract delegation ────────────────────────────────────────────

  group('runningContract', () {
    test('delegates to Session.composeRunningContract with empty choices when no __branch_choices', () {
      final outcome = Outcome(
        id: 'x',
        contractDelta: Contract(fields: {
          'x_field': const FieldSpec(type: 'String', required: true),
        }),
        handoff: null,
      );
      final navigator = OutcomeNavigator(outcome);
      final session = sampleSession(
        currentNode: outcome,
        answers: {'x_field': 'val'},
      );
      final contract = navigator.runningContract(session);
      expect(contract.fields.containsKey('x_field'), isTrue);
    });
  });
}
