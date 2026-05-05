import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/answer.dart';
import 'package:genuiform/src/models/engagement_signal.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';

void main() {
  group('Answer', () {
    final stepSpec = QuizStepSpec(
      id: 'step_name',
      title: 'What is your name?',
      inputType: QuizInputType.text,
    );
    final timestamp = DateTime.utc(2026, 5, 5, 12, 0, 0);

    test('constructs with all fields', () {
      final a = Answer(
        stepId: 'step_name',
        stepSpec: stepSpec,
        answer: 'Alice',
        timestamp: timestamp,
        engagement: EngagementSignal.strong,
      );
      expect(a.stepId, 'step_name');
      expect(a.answer, 'Alice');
      expect(a.engagement, EngagementSignal.strong);
    });

    test('equality holds', () {
      final a = Answer(
        stepId: 'step_name',
        stepSpec: stepSpec,
        answer: 'Alice',
        timestamp: timestamp,
        engagement: EngagementSignal.strong,
      );
      final b = Answer(
        stepId: 'step_name',
        stepSpec: stepSpec,
        answer: 'Alice',
        timestamp: timestamp,
        engagement: EngagementSignal.strong,
      );
      expect(a, equals(b));
    });

    test('JSON round-trip with string answer', () {
      final a = Answer(
        stepId: 'step_name',
        stepSpec: stepSpec,
        answer: 'Bob',
        timestamp: timestamp,
        engagement: EngagementSignal.weak,
      );
      final json = a.toJson();
      expect(json['engagement'], 'weak');
      final restored = Answer.fromJson(json);
      expect(restored, equals(a));
    });

    test('JSON round-trip with list answer', () {
      final a = Answer(
        stepId: 'step_goals',
        stepSpec: QuizStepSpec(
          id: 'step_goals',
          title: 'Goals?',
          inputType: QuizInputType.multiChoice,
        ),
        answer: ['fitness', 'health'],
        timestamp: timestamp,
        engagement: EngagementSignal.strong,
      );
      final json = a.toJson();
      final restored = Answer.fromJson(json);
      expect(restored, equals(a));
    });

    test('JSON round-trip with numeric answer', () {
      final a = Answer(
        stepId: 'step_budget',
        stepSpec: QuizStepSpec(
          id: 'step_budget',
          title: 'Budget?',
          inputType: QuizInputType.number,
        ),
        answer: 5000,
        timestamp: timestamp,
        engagement: EngagementSignal.negative,
      );
      final json = a.toJson();
      final restored = Answer.fromJson(json);
      expect(restored, equals(a));
    });
  });
}
