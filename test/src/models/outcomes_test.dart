import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/contract.dart';
import 'package:genuiform/src/models/field_spec.dart';
import 'package:genuiform/src/models/outcomes.dart';

void main() {
  // Shared fixtures
  final emailField = const FieldSpec(type: 'String', required: true);
  final workoutFields = {'goals': const FieldSpec(type: 'List', required: true)};

  final accountContract = Contract(fields: {'email': emailField});
  final workoutContract = Contract(fields: workoutFields);
  final mealContract = Contract(
    fields: {'dietary_restrictions': const FieldSpec(type: 'List', required: true)},
  );
  final macroContract = Contract(
    fields: {'protein_target_g': const FieldSpec(type: 'int', required: true)},
  );

  group('Outcome', () {
    test('constructs with id and contractDelta', () {
      final o = Outcome(
        id: 'lead_qualified',
        contractDelta: accountContract,
        handoff: (_) {},
      );
      expect(o.id, 'lead_qualified');
      expect(o.contractDelta.fields.keys, contains('email'));
    });

    test('JSON round-trip (no handoff in JSON)', () {
      final o = Outcome(
        id: 'lead_qualified',
        contractDelta: accountContract,
        handoff: (_) {},
      );
      final json = o.toJson();
      expect(json['node_type'], 'Outcome');
      expect(json['id'], 'lead_qualified');
      expect(json.containsKey('handoff'), isFalse);

      final restored = OutcomeNode.fromJson(json) as Outcome;
      expect(restored.id, 'lead_qualified');
      expect(restored.handoff, isNull);
    });

    test('equality by value (ignoring handoff)', () {
      final a = Outcome(
        id: 'same',
        contractDelta: accountContract,
        handoff: (_) {},
      );
      final b = Outcome(
        id: 'same',
        contractDelta: accountContract,
        handoff: (_) {},
      );
      // Freezed equality checks all fields — handoffs are functions and not
      // equal by reference, so we test id/contractDelta manually:
      expect(a.id, b.id);
      expect(a.contractDelta, b.contractDelta);
    });
  });

  group('Layer', () {
    test('constructs with next node', () {
      final inner = Outcome(
        id: 'full_setup',
        contractDelta: workoutContract,
        handoff: (_) {},
      );
      final outer = Layer(
        id: 'account_only',
        contractDelta: accountContract,
        handoff: (_) {},
        next: inner,
      );
      expect(outer.id, 'account_only');
      expect(outer.next, isA<Outcome>());
    });

    test('constructs with null next', () {
      final l = Layer(
        id: 'deepest',
        contractDelta: accountContract,
        handoff: (_) {},
      );
      expect(l.next, isNull);
    });

    test('JSON round-trip', () {
      final inner = Outcome(
        id: 'full',
        contractDelta: workoutContract,
        handoff: (_) {},
      );
      final layer = Layer(
        id: 'base',
        contractDelta: accountContract,
        handoff: (_) {},
        next: inner,
      );
      final json = layer.toJson();
      expect(json['node_type'], 'Layer');
      final restored = OutcomeNode.fromJson(json) as Layer;
      expect(restored.id, 'base');
      expect(restored.next, isA<Outcome>());
    });
  });

  group('Branch', () {
    test('constructs with options', () {
      final option = BranchOption(
        id: 'book_call',
        criterion: 'qualified + budget',
        contractDelta: null,
        child: Outcome(
          id: 'book_call_outcome',
          contractDelta: accountContract,
          handoff: (_) {},
        ),
      );
      final branch = Branch(id: 'lead_split', options: [option]);
      expect(branch.options.length, 1);
      expect(branch.options.first.id, 'book_call');
    });

    test('JSON round-trip', () {
      final branch = Branch(
        id: 'nutrition_path',
        options: [
          BranchOption(
            id: 'with_meal_plan',
            criterion: 'wants meals planned',
            contractDelta: mealContract,
            child: Outcome(
              id: 'full_meal_plan',
              contractDelta: Contract(fields: {}),
              handoff: (_) {},
            ),
          ),
          BranchOption(
            id: 'with_macros',
            criterion: 'wants macros only',
            contractDelta: macroContract,
            child: Outcome(
              id: 'full_macros',
              contractDelta: Contract(fields: {}),
              handoff: (_) {},
            ),
          ),
          BranchOption(
            id: 'skip_nutrition',
            criterion: 'opted out',
            contractDelta: null, // nullable per spec v0.4 Fix A
            child: Outcome(
              id: 'workout_only',
              contractDelta: Contract(fields: {}),
              handoff: (_) {},
            ),
          ),
        ],
      );
      final json = branch.toJson();
      expect(json['node_type'], 'Branch');
      final restored = OutcomeNode.fromJson(json) as Branch;
      expect(restored.id, 'nutrition_path');
      expect(restored.options.length, 3);
      expect(restored.options[2].contractDelta, isNull);
    });
  });

  group('BranchOption', () {
    test('nullable contractDelta (Spec v0.4 Fix A)', () {
      final opt = BranchOption(
        id: 'skip',
        criterion: 'opted out',
        contractDelta: null,
        child: Outcome(
          id: 'out',
          contractDelta: Contract(fields: {}),
          handoff: (_) {},
        ),
      );
      expect(opt.contractDelta, isNull);
    });

    test('non-null contractDelta', () {
      final opt = BranchOption(
        id: 'meal',
        criterion: 'wants meals',
        contractDelta: mealContract,
        child: Outcome(
          id: 'full_meal',
          contractDelta: Contract(fields: {}),
          handoff: (_) {},
        ),
      );
      expect(opt.contractDelta, isNotNull);
    });
  });

  group('Tree-walk helpers', () {
    // Build: Layer('a') → Layer('b') → Outcome('c')
    late OutcomeNode tree;

    setUp(() {
      final c = Outcome(
        id: 'c',
        contractDelta: Contract(fields: {}),
        handoff: (_) {},
      );
      final b = Layer(
        id: 'b',
        contractDelta: Contract(fields: {'b_field': const FieldSpec(type: 'String', required: true)}),
        handoff: (_) {},
        next: c,
      );
      final a = Layer(
        id: 'a',
        contractDelta: Contract(fields: {'a_field': const FieldSpec(type: 'String', required: true)}),
        handoff: (_) {},
        next: b,
      );
      tree = a;
    });

    group('pathTo', () {
      test('returns [root] when target is root', () {
        final path = tree.pathTo('a');
        expect(path.map((n) => n.id), ['a']);
      });

      test('returns full path to a deep node', () {
        final path = tree.pathTo('c');
        expect(path.map((n) => n.id), ['a', 'b', 'c']);
      });

      test('returns path stopping at intermediate node', () {
        final path = tree.pathTo('b');
        expect(path.map((n) => n.id), ['a', 'b']);
      });

      test('throws StateError when node not found', () {
        expect(() => tree.pathTo('nonexistent'), throwsStateError);
      });
    });

    group('descendants', () {
      test('DFS pre-order: a, b, c for ladder', () {
        final ids = tree.descendants().map((n) => n.id).toList();
        expect(ids, ['a', 'b', 'c']);
      });

      test('single Outcome has one descendant (itself)', () {
        final o = Outcome(
          id: 'solo',
          contractDelta: Contract(fields: {}),
          handoff: (_) {},
        );
        final ids = o.descendants().map((n) => n.id).toList();
        expect(ids, ['solo']);
      });

      test('Branch includes all options children', () {
        final branch = Branch(
          id: 'split',
          options: [
            BranchOption(
              id: 'opt_a',
              criterion: 'a',
              child: Outcome(id: 'leaf_a', contractDelta: Contract(fields: {}), handoff: (_) {}),
            ),
            BranchOption(
              id: 'opt_b',
              criterion: 'b',
              child: Outcome(id: 'leaf_b', contractDelta: Contract(fields: {}), handoff: (_) {}),
            ),
          ],
        );
        final ids = branch.descendants().map((n) => n.id).toList();
        expect(ids, containsAll(['split', 'leaf_a', 'leaf_b']));
      });
    });
  });
}
