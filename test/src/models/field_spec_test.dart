import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/field_spec.dart';
import 'package:genuiform/src/models/num_range.dart';

void main() {
  group('FieldSpec', () {
    test('constructs with required type and required flag', () {
      const f = FieldSpec(type: 'String', required: true);
      expect(f.type, 'String');
      expect(f.required, isTrue);
      expect(f.description, isNull);
      expect(f.enumValues, isNull);
      expect(f.range, isNull);
      expect(f.minLength, isNull);
      expect(f.maxLength, isNull);
    });

    test('constructs with all fields', () {
      const f = FieldSpec(
        type: 'int',
        required: false,
        description: 'Monthly budget',
        enumValues: [100, 200, 300],
        range: NumRange(min: 0, max: 10000),
        minLength: 1,
        maxLength: 50,
      );
      expect(f.type, 'int');
      expect(f.required, isFalse);
      expect(f.description, 'Monthly budget');
      expect(f.enumValues, [100, 200, 300]);
      expect(f.range, const NumRange(min: 0, max: 10000));
      expect(f.minLength, 1);
      expect(f.maxLength, 50);
    });

    test('equality holds across identical instances', () {
      const a = FieldSpec(type: 'String', required: true);
      const b = FieldSpec(type: 'String', required: true);
      expect(a, equals(b));
    });

    test('JSON round-trip minimal', () {
      const f = FieldSpec(type: 'String', required: true);
      final json = f.toJson();
      expect(json['type'], 'String');
      expect(json['required'], isTrue);
      final restored = FieldSpec.fromJson(json);
      expect(restored, equals(f));
    });

    test('JSON round-trip with enum values and range', () {
      const f = FieldSpec(
        type: 'String',
        required: true,
        description: 'Timeline',
        enumValues: ['immediate', '1-3 months'],
        range: NumRange(min: 0, max: 100),
        minLength: 2,
        maxLength: 20,
      );
      final json = f.toJson();
      final restored = FieldSpec.fromJson(json);
      expect(restored, equals(f));
    });

    test('kFieldTypeFromString has expected keys', () {
      expect(kFieldTypeFromString.keys, containsAll([
        'String', 'int', 'double', 'bool', 'DateTime', 'List', 'Enum',
      ]));
    });

    test('all valid type strings accepted', () {
      for (final typeName in ['String', 'int', 'double', 'bool', 'DateTime', 'List', 'Enum']) {
        final f = FieldSpec(type: typeName, required: false);
        expect(f.type, typeName);
      }
    });
  });
}
