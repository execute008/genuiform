import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/contract.dart';
import 'package:genuiform/src/models/field_spec.dart';
import 'package:genuiform/src/models/num_range.dart';

void main() {
  group('Contract', () {
    const nameField = FieldSpec(type: 'String', required: true);
    const emailField = FieldSpec(type: 'String', required: true);
    const budgetField = FieldSpec(
      type: 'int',
      required: false,
      range: NumRange(min: 0, max: 100000),
    );

    test('constructs with fields only', () {
      final c = Contract(fields: {'name': nameField});
      expect(c.fields['name'], equals(nameField));
      expect(c.exploratoryFields, isNull);
    });

    test('constructs with exploratory fields', () {
      final c = Contract(
        fields: {'name': nameField},
        exploratoryFields: {'extra_note': 'something'},
      );
      expect(c.exploratoryFields, {'extra_note': 'something'});
    });

    test('equality holds', () {
      final a = Contract(fields: {'name': nameField});
      final b = Contract(fields: {'name': nameField});
      expect(a, equals(b));
    });

    test('JSON round-trip minimal', () {
      final c = Contract(fields: {'name': nameField});
      final json = c.toJson();
      final restored = Contract.fromJson(json);
      expect(restored, equals(c));
    });

    test('JSON round-trip with exploratory fields', () {
      final c = Contract(
        fields: {'email': emailField, 'budget': budgetField},
        exploratoryFields: {'notes': 'any'},
      );
      final json = c.toJson();
      final restored = Contract.fromJson(json);
      expect(restored, equals(c));
    });

    group('Contract.merge', () {
      test('combines fields from both contracts', () {
        final base = Contract(fields: {'name': nameField});
        final delta = Contract(fields: {'email': emailField});
        final merged = base.merge(delta);
        expect(merged.fields.keys, containsAll(['name', 'email']));
      });

      test('other wins on field conflict', () {
        const altNameField = FieldSpec(type: 'String', required: false);
        final base = Contract(fields: {'name': nameField});
        final delta = Contract(fields: {'name': altNameField});
        final merged = base.merge(delta);
        expect(merged.fields['name']!.required, isFalse);
      });

      test('merges exploratory fields, other wins on conflict', () {
        final base = Contract(
          fields: {'name': nameField},
          exploratoryFields: {'a': '1', 'b': '2'},
        );
        final delta = Contract(
          fields: {'email': emailField},
          exploratoryFields: {'b': 'OVERRIDE', 'c': '3'},
        );
        final merged = base.merge(delta);
        expect(merged.exploratoryFields!['a'], '1');
        expect(merged.exploratoryFields!['b'], 'OVERRIDE');
        expect(merged.exploratoryFields!['c'], '3');
      });

      test('null exploratory fields handled gracefully', () {
        final base = Contract(fields: {'name': nameField});
        final delta = Contract(
          fields: {'email': emailField},
          exploratoryFields: {'extra': 'data'},
        );
        final merged = base.merge(delta);
        expect(merged.exploratoryFields, {'extra': 'data'});
      });

      test('merge with both null exploratory fields stays null', () {
        final base = Contract(fields: {'name': nameField});
        final delta = Contract(fields: {'email': emailField});
        final merged = base.merge(delta);
        expect(merged.exploratoryFields, isNull);
      });

      test('returns new contract, does not mutate original', () {
        final base = Contract(fields: {'name': nameField});
        final delta = Contract(fields: {'email': emailField});
        base.merge(delta);
        expect(base.fields.length, 1);
      });
    });
  });
}
