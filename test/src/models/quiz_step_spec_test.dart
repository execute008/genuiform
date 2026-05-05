import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_choice.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';

void main() {
  group('QuizStepSpec', () {
    test('constructs with required fields', () {
      final spec = QuizStepSpec(
        id: 'step_name',
        title: 'What is your name?',
        inputType: QuizInputType.text,
      );
      expect(spec.id, 'step_name');
      expect(spec.title, 'What is your name?');
      expect(spec.inputType, QuizInputType.text);
      expect(spec.description, isNull);
      expect(spec.initialValue, isNull);
      expect(spec.configuration, isNull);
      expect(spec.validationMessage, isNull);
      expect(spec.choices, isNull);
    });

    test('constructs with all fields', () {
      const choices = [QuizChoice(id: 'a', label: 'A'), QuizChoice(id: 'b', label: 'B')];
      final spec = QuizStepSpec(
        id: 'step_goals',
        title: 'What are your goals?',
        description: 'Select all that apply',
        inputType: QuizInputType.multiChoice,
        initialValue: null,
        configuration: {'maxSelections': 3},
        validationMessage: 'Please select at least one',
        choices: choices,
      );
      expect(spec.choices, choices);
      expect(spec.validationMessage, 'Please select at least one');
    });

    test('no Flutter imports — iconName is String on choices', () {
      const choice = QuizChoice(id: 'x', label: 'X', iconName: 'star');
      expect(choice.iconName, isA<String>());
    });

    test('equality holds', () {
      final a = QuizStepSpec(
        id: 'step_1',
        title: 'Title',
        inputType: QuizInputType.text,
      );
      final b = QuizStepSpec(
        id: 'step_1',
        title: 'Title',
        inputType: QuizInputType.text,
      );
      expect(a, equals(b));
    });

    test('JSON round-trip minimal', () {
      final spec = QuizStepSpec(
        id: 'step_name',
        title: 'Your name?',
        inputType: QuizInputType.text,
      );
      final json = spec.toJson();
      expect(json['inputType'], 'text');
      final restored = QuizStepSpec.fromJson(json);
      expect(restored, equals(spec));
    });

    test('JSON round-trip with choices', () {
      final spec = QuizStepSpec(
        id: 'step_goals',
        title: 'Goals?',
        inputType: QuizInputType.multiChoice,
        choices: const [
          QuizChoice(id: 'fitness', label: 'Fitness', iconName: 'dumbbell'),
          QuizChoice(id: 'health', label: 'Health'),
        ],
        configuration: {'maxSelections': 5},
      );
      final json = spec.toJson();
      final restored = QuizStepSpec.fromJson(json);
      expect(restored, equals(spec));
    });

    test('JSON round-trip with slider inputType', () {
      final spec = QuizStepSpec(
        id: 'step_intensity',
        title: 'Intensity level?',
        inputType: QuizInputType.slider,
        configuration: {'min': 1, 'max': 10},
      );
      final json = spec.toJson();
      expect(json['inputType'], 'slider');
      final restored = QuizStepSpec.fromJson(json);
      expect(restored, equals(spec));
    });

    test('inputType noneJustInformation serialises correctly', () {
      final spec = QuizStepSpec(
        id: 'intro',
        title: 'Welcome to the form!',
        inputType: QuizInputType.noneJustInformation,
      );
      final json = spec.toJson();
      expect(json['inputType'], 'noneJustInformation');
    });
  });
}
