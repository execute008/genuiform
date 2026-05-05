import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/num_range.dart';

void main() {
  group('NumRange', () {
    test('constructs with both min and max', () {
      const r = NumRange(min: 10, max: 200);
      expect(r.min, 10);
      expect(r.max, 200);
    });

    test('constructs with min only', () {
      const r = NumRange(min: 0);
      expect(r.min, 0);
      expect(r.max, isNull);
    });

    test('constructs with max only', () {
      const r = NumRange(max: 100);
      expect(r.min, isNull);
      expect(r.max, 100);
    });

    test('constructs with both nullable', () {
      const r = NumRange();
      expect(r.min, isNull);
      expect(r.max, isNull);
    });

    test('equality holds', () {
      const a = NumRange(min: 5, max: 10);
      const b = NumRange(min: 5, max: 10);
      expect(a, equals(b));
    });

    test('inequality when values differ', () {
      const a = NumRange(min: 5, max: 10);
      const b = NumRange(min: 5, max: 20);
      expect(a, isNot(equals(b)));
    });

    test('JSON round-trip with both values', () {
      const r = NumRange(min: 15, max: 240);
      final json = r.toJson();
      final restored = NumRange.fromJson(json);
      expect(restored, equals(r));
    });

    test('JSON round-trip with null values', () {
      const r = NumRange();
      final json = r.toJson();
      final restored = NumRange.fromJson(json);
      expect(restored, equals(r));
    });

    test('JSON from map with explicit nulls', () {
      final json = <String, dynamic>{'min': null, 'max': null};
      final r = NumRange.fromJson(json);
      expect(r.min, isNull);
      expect(r.max, isNull);
    });
  });
}
