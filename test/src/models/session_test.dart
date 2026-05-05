import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/contract.dart';
import 'package:genuiform/src/models/engagement_signal.dart';
import 'package:genuiform/src/models/field_spec.dart';
import 'package:genuiform/src/models/outcomes.dart';
import 'package:genuiform/src/models/session.dart';
import 'package:genuiform/src/models/session_status.dart';

void main() {
  // ── Fixtures ──────────────────────────────────────────────────────────────

  const emailField = FieldSpec(type: 'String', required: true);
  const goalsField = FieldSpec(type: 'List', required: true);
  const dietField = FieldSpec(type: 'List', required: true);
  const macroField = FieldSpec(type: 'int', required: true);

  final accountContract = Contract(fields: {'email': emailField});
  final workoutContract = Contract(fields: {'goals': goalsField});
  final mealContract = Contract(fields: {'dietary_restrictions': dietField});
  final macroContract = Contract(fields: {'protein_target_g': macroField});

  // ── Session.composeRunningContract ────────────────────────────────────────

  group('Session.composeRunningContract', () {
    test('single Outcome: running contract equals the outcome contractDelta', () {
      final outcome = Outcome(
        id: 'lead_qualified',
        contractDelta: accountContract,
        handoff: (_) {},
      );
      final running = Session.composeRunningContract(
        root: outcome,
        currentNode: outcome,
      );
      expect(running.fields.keys, containsAll(['email']));
    });

    test('three-Layer ladder: merges all contractDeltas on path to currentNode', () {
      // Layer('a') → Layer('b') → Layer('c')
      // Each layer adds one field.
      final layerC = Layer(
        id: 'c',
        contractDelta: Contract(fields: {'c_field': emailField}),
        handoff: (_) {},
      );
      final layerB = Layer(
        id: 'b',
        contractDelta: Contract(fields: {'b_field': goalsField}),
        handoff: (_) {},
        next: layerC,
      );
      final layerA = Layer(
        id: 'a',
        contractDelta: Contract(fields: {'a_field': emailField}),
        handoff: (_) {},
        next: layerB,
      );

      final running = Session.composeRunningContract(
        root: layerA,
        currentNode: layerC,
      );
      expect(running.fields.keys, containsAll(['a_field', 'b_field', 'c_field']));
    });

    test('ladder stopped at intermediate layer: only earlier deltas included', () {
      final layerB = Layer(
        id: 'b',
        contractDelta: Contract(fields: {'b_field': goalsField}),
        handoff: (_) {},
      );
      final layerA = Layer(
        id: 'a',
        contractDelta: Contract(fields: {'a_field': emailField}),
        handoff: (_) {},
        next: layerB,
      );

      final running = Session.composeRunningContract(
        root: layerA,
        currentNode: layerA,
      );
      expect(running.fields.keys, contains('a_field'));
      expect(running.fields.containsKey('b_field'), isFalse);
    });

    test('ladder + branch: chosen BranchOption contractDelta is included (GymGeist shape)', () {
      // Mirrors spec §11.2:
      // Layer('account_only') → Layer('with_workout_plan') →
      //   Branch('nutrition_path', [
      //     BranchOption('with_meal_plan', contractDelta: mealContract, child: Outcome('full_meal_plan')),
      //     BranchOption('with_macros', contractDelta: macroContract, child: Outcome('full_macros')),
      //     BranchOption('skip_nutrition', contractDelta: null, child: Outcome('workout_only')),
      //   ])
      final mealOutcome = Outcome(
        id: 'full_meal_plan',
        contractDelta: Contract(fields: {}),
        handoff: (_) {},
      );
      final macroOutcome = Outcome(
        id: 'full_macros',
        contractDelta: Contract(fields: {}),
        handoff: (_) {},
      );
      final workoutOutcome = Outcome(
        id: 'workout_only',
        contractDelta: Contract(fields: {}),
        handoff: (_) {},
      );
      final nutritionBranch = Branch(
        id: 'nutrition_path',
        options: [
          BranchOption(
            id: 'with_meal_plan',
            criterion: 'wants meals planned',
            contractDelta: mealContract,
            child: mealOutcome,
          ),
          BranchOption(
            id: 'with_macros',
            criterion: 'wants macros',
            contractDelta: macroContract,
            child: macroOutcome,
          ),
          BranchOption(
            id: 'skip_nutrition',
            criterion: 'opts out',
            contractDelta: null,
            child: workoutOutcome,
          ),
        ],
      );
      final withWorkout = Layer(
        id: 'with_workout_plan',
        contractDelta: workoutContract,
        handoff: (_) {},
        next: nutritionBranch,
      );
      final accountOnly = Layer(
        id: 'account_only',
        contractDelta: accountContract,
        handoff: (_) {},
        next: withWorkout,
      );

      // User chose 'with_meal_plan' branch option
      final running = Session.composeRunningContract(
        root: accountOnly,
        currentNode: mealOutcome,
        chosenBranchOptions: {'nutrition_path': 'with_meal_plan'},
      );

      expect(
        running.fields.keys,
        containsAll(['email', 'goals', 'dietary_restrictions']),
      );
      // macros should NOT be included (different branch)
      expect(running.fields.containsKey('protein_target_g'), isFalse);
    });

    test('branch with null contractDelta (skip_nutrition): no extra fields added', () {
      final workoutOutcome = Outcome(
        id: 'workout_only',
        contractDelta: Contract(fields: {}),
        handoff: (_) {},
      );
      final branch = Branch(
        id: 'nutrition_path',
        options: [
          BranchOption(
            id: 'skip_nutrition',
            criterion: 'opts out',
            contractDelta: null,
            child: workoutOutcome,
          ),
        ],
      );
      final layerA = Layer(
        id: 'account_only',
        contractDelta: accountContract,
        handoff: (_) {},
        next: branch,
      );

      final running = Session.composeRunningContract(
        root: layerA,
        currentNode: workoutOutcome,
        chosenBranchOptions: {'nutrition_path': 'skip_nutrition'},
      );

      expect(running.fields.keys, containsAll(['email']));
      // No extra nutrition fields
      expect(running.fields.length, 1);
    });
  });

  // ── Session construction & JSON ───────────────────────────────────────────

  group('Session', () {
    final outcome = Outcome(
      id: 'result',
      contractDelta: accountContract,
      handoff: (_) {},
    );

    test('constructs with required fields', () {
      final session = Session(
        currentNode: outcome,
        history: const [],
        answers: const {},
        runningContract: accountContract,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.strong,
      );
      expect(session.currentNode.id, 'result');
      expect(session.status, SessionStatus.active);
      expect(session.reachedOutcome, isNull);
    });

    test('JSON round-trip', () {
      final session = Session(
        currentNode: outcome,
        history: const [],
        answers: const {'email': 'alice@example.com'},
        runningContract: accountContract,
        status: SessionStatus.completed,
        lastSignal: EngagementSignal.strong,
        reachedOutcome: outcome,
      );
      final json = session.toJson();
      expect(json['status'], 'completed');
      expect(json['lastSignal'], 'strong');
      final restored = Session.fromJson(json);
      expect(restored.status, SessionStatus.completed);
      expect(restored.answers['email'], 'alice@example.com');
    });

    test('JSON round-trip with engagement negative', () {
      final session = Session(
        currentNode: outcome,
        history: const [],
        answers: const {},
        runningContract: accountContract,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.negative,
      );
      final json = session.toJson();
      expect(json['lastSignal'], 'negative');
      final restored = Session.fromJson(json);
      expect(restored.lastSignal, EngagementSignal.negative);
    });

    test('equality holds for matching sessions', () {
      final a = Session(
        currentNode: outcome,
        history: const [],
        answers: const {},
        runningContract: accountContract,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      final b = Session(
        currentNode: outcome,
        history: const [],
        answers: const {},
        runningContract: accountContract,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      expect(a, equals(b));
    });
  });
}
