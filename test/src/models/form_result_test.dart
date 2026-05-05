import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/answer.dart';
import 'package:genuiform/src/models/contract.dart';
import 'package:genuiform/src/models/engagement_signal.dart';
import 'package:genuiform/src/models/field_spec.dart';
import 'package:genuiform/src/models/form_result.dart';
import 'package:genuiform/src/models/outcomes.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/models/session_status.dart';

void main() {
  const emailField = FieldSpec(type: 'String', required: true);
  final accountContract = Contract(fields: {'email': emailField});
  final timestamp = DateTime.utc(2026, 5, 5, 12, 0);

  final outcome = Outcome(
    id: 'lead_qualified',
    contractDelta: accountContract,
    handoff: (_) {},
  );

  final answer = Answer(
    stepId: 'step_email',
    stepSpec: QuizStepSpec(
      id: 'step_email',
      title: 'Email?',
      inputType: QuizInputType.text,
    ),
    answer: 'alice@example.com',
    timestamp: timestamp,
    engagement: EngagementSignal.strong,
  );

  group('FormResult', () {
    test('constructs with all fields', () {
      final result = FormResult(
        collectedFields: const {'email': 'alice@example.com'},
        reachedOutcome: outcome,
        history: [answer],
        status: SessionStatus.completed,
      );
      expect(result.collectedFields['email'], 'alice@example.com');
      expect(result.reachedOutcome?.id, 'lead_qualified');
      expect(result.history.length, 1);
      expect(result.status, SessionStatus.completed);
    });

    test('constructs with null reachedOutcome (abandoned)', () {
      final result = FormResult(
        collectedFields: const {},
        reachedOutcome: null,
        history: const [],
        status: SessionStatus.abandoned,
      );
      expect(result.reachedOutcome, isNull);
      expect(result.status, SessionStatus.abandoned);
    });

    test('equality holds', () {
      final a = FormResult(
        collectedFields: const {'email': 'x'},
        reachedOutcome: outcome,
        history: const [],
        status: SessionStatus.completed,
      );
      final b = FormResult(
        collectedFields: const {'email': 'x'},
        reachedOutcome: outcome,
        history: const [],
        status: SessionStatus.completed,
      );
      expect(a, equals(b));
    });

    test('JSON round-trip', () {
      final result = FormResult(
        collectedFields: const {'email': 'alice@example.com'},
        reachedOutcome: outcome,
        history: [answer],
        status: SessionStatus.completed,
      );
      final json = result.toJson();
      expect(json['status'], 'completed');
      final restored = FormResult.fromJson(json);
      expect(restored.status, SessionStatus.completed);
      expect(restored.collectedFields['email'], 'alice@example.com');
    });

    test('JSON round-trip with null reachedOutcome', () {
      final result = FormResult(
        collectedFields: const {},
        reachedOutcome: null,
        history: const [],
        status: SessionStatus.abandoned,
      );
      final json = result.toJson();
      final restored = FormResult.fromJson(json);
      expect(restored.reachedOutcome, isNull);
      expect(restored.status, SessionStatus.abandoned);
    });
  });
}
