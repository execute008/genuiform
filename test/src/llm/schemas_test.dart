import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/llm/schemas.dart';

void main() {
  group('generativeStrategyResponseSchema', () {
    late Map<String, dynamic> schema;

    setUp(() {
      schema = generativeStrategyResponseSchema();
    });

    test('returns a non-null map', () {
      expect(schema, isNotNull);
      expect(schema, isA<Map<String, dynamic>>());
    });

    test('top-level type is object', () {
      expect(schema['type'], 'object');
    });

    test('has required field listing decision and engagement', () {
      final required = schema['required'] as List<dynamic>;
      expect(required, containsAll(['decision', 'engagement']));
    });

    test('properties map contains all expected top-level keys', () {
      final props = schema['properties'] as Map<String, dynamic>;
      expect(
        props.keys,
        containsAll([
          'decision',
          'step',
          'branch_resolution',
          'exit_offer',
          'outcome',
          'engagement',
        ]),
      );
    });

    group('decision property', () {
      late Map<String, dynamic> decision;

      setUp(() {
        final props = schema['properties'] as Map<String, dynamic>;
        decision = props['decision'] as Map<String, dynamic>;
      });

      test('is type string', () {
        expect(decision['type'], 'string');
      });

      test('enum contains all four decision values', () {
        final enumValues = decision['enum'] as List<dynamic>;
        expect(
          enumValues,
          containsAll(['ask_step', 'offer_exit', 'resolve_branch', 'complete']),
        );
      });
    });

    group('engagement property', () {
      late Map<String, dynamic> engagement;

      setUp(() {
        final props = schema['properties'] as Map<String, dynamic>;
        engagement = props['engagement'] as Map<String, dynamic>;
      });

      test('is type string', () {
        expect(engagement['type'], 'string');
      });

      test('enum contains strong, weak, negative', () {
        final enumValues = engagement['enum'] as List<dynamic>;
        expect(enumValues, containsAll(['strong', 'weak', 'negative']));
      });
    });

    group('branch_resolution property', () {
      late Map<String, dynamic> branchResolution;

      setUp(() {
        final props = schema['properties'] as Map<String, dynamic>;
        branchResolution = props['branch_resolution'] as Map<String, dynamic>;
      });

      test('is type object', () {
        expect(branchResolution['type'], 'object');
      });

      test('has branch_id, option_id, and rationale properties', () {
        final bProps = branchResolution['properties'] as Map<String, dynamic>;
        expect(
          bProps.keys,
          containsAll(['branch_id', 'option_id', 'rationale']),
        );
      });

      test('branch_id and option_id are string type', () {
        final bProps = branchResolution['properties'] as Map<String, dynamic>;
        expect((bProps['branch_id'] as Map<String, dynamic>)['type'], 'string');
        expect((bProps['option_id'] as Map<String, dynamic>)['type'], 'string');
      });
    });

    group('outcome property', () {
      late Map<String, dynamic> outcome;

      setUp(() {
        final props = schema['properties'] as Map<String, dynamic>;
        outcome = props['outcome'] as Map<String, dynamic>;
      });

      test('is type object', () {
        expect(outcome['type'], 'object');
      });

      test('has outcome_id and summary properties', () {
        final oProps = outcome['properties'] as Map<String, dynamic>;
        expect(oProps.keys, containsAll(['outcome_id', 'summary']));
      });
    });

    group('step property', () {
      test('step is an object type with QuizStepSpec-compatible properties', () {
        final props = schema['properties'] as Map<String, dynamic>;
        final step = props['step'] as Map<String, dynamic>;
        expect(step['type'], 'object');
        final stepProps = step['properties'] as Map<String, dynamic>;
        // Verify the keys that QuizStepSpec.toJson() will emit:
        // id, title, description, inputType, choices.
        expect(
          stepProps.keys,
          containsAll(['id', 'title', 'description', 'inputType', 'choices']),
        );
      });

      test('inputType enum contains all valid QuizInputType values', () {
        final props = schema['properties'] as Map<String, dynamic>;
        final step = props['step'] as Map<String, dynamic>;
        final stepProps = step['properties'] as Map<String, dynamic>;
        final inputType = stepProps['inputType'] as Map<String, dynamic>;
        final enumValues = inputType['enum'] as List<dynamic>;

        expect(
          enumValues,
          containsAll([
            'slider',
            'choice',
            'multiChoice',
            'text',
            'number',
            'date',
            'noneJustInformation',
          ]),
        );
      });
    });

    group('exit_offer property', () {
      test('exit_offer is object type', () {
        final props = schema['properties'] as Map<String, dynamic>;
        final exitOffer = props['exit_offer'] as Map<String, dynamic>;
        expect(exitOffer['type'], 'object');
      });
    });

    test('schema is a fresh map on each call (not the same reference)', () {
      final schema1 = generativeStrategyResponseSchema();
      final schema2 = generativeStrategyResponseSchema();
      expect(identical(schema1, schema2), isFalse);
    });
  });
}
