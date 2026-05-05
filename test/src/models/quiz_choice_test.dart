import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_choice.dart';

void main() {
  group('QuizChoice', () {
    test('constructs with required fields only', () {
      const c = QuizChoice(id: 'opt_a', label: 'Option A');
      expect(c.id, 'opt_a');
      expect(c.label, 'Option A');
      expect(c.description, isNull);
      expect(c.iconName, isNull);
      expect(c.isTextField, isFalse);
      expect(c.configuration, isNull);
    });

    test('constructs with all fields', () {
      const c = QuizChoice(
        id: 'vegetarian',
        label: 'Vegetarian',
        description: 'No meat',
        iconName: 'leaf',
        isTextField: false,
        configuration: {'color': 'green'},
      );
      expect(c.id, 'vegetarian');
      expect(c.label, 'Vegetarian');
      expect(c.description, 'No meat');
      expect(c.iconName, 'leaf');
      expect(c.isTextField, isFalse);
      expect(c.configuration, {'color': 'green'});
    });

    test('iconName is a String not an IconData — no Flutter import', () {
      const c = QuizChoice(id: 'x', label: 'X', iconName: 'star');
      expect(c.iconName, isA<String>());
    });

    test('equality holds', () {
      const a = QuizChoice(id: 'a', label: 'A');
      const b = QuizChoice(id: 'a', label: 'A');
      expect(a, equals(b));
    });

    test('JSON round-trip minimal', () {
      const c = QuizChoice(id: 'opt_a', label: 'Option A');
      final json = c.toJson();
      final restored = QuizChoice.fromJson(json);
      expect(restored, equals(c));
    });

    test('JSON round-trip with all fields', () {
      const c = QuizChoice(
        id: 'vegan',
        label: 'Vegan',
        description: 'Plant-based only',
        iconName: 'sprout',
        isTextField: false,
        configuration: {'accent': '#4CAF50'},
      );
      final json = c.toJson();
      final restored = QuizChoice.fromJson(json);
      expect(restored, equals(c));
    });

    test('isTextField field in quiz choice', () {
      const c = QuizChoice(id: 'other', label: 'Other', isTextField: true);
      final json = c.toJson();
      final restored = QuizChoice.fromJson(json);
      expect(restored.isTextField, isTrue);
    });
  });
}
