// End-to-end integration test for the freelance qualification form.
//
// **Never run by `flutter test`.** This file lives under `integration_test/`
// and is only executed manually with the environment variable
// `GENUIFORM_RUN_INTEGRATION=1` (or `true`) set.
//
// Run with:
//   GENUIFORM_RUN_INTEGRATION=1 \
//   GEMINI_API_KEY=<aistudio-api-key> \
//   flutter test integration_test/freelance_qualification_e2e_test.dart \
//     --dart-define=GENUIFORM_RUN_INTEGRATION=1 \
//     --dart-define=GEMINI_API_KEY=<key>
//
// All tests in this file are skipped unless the gate is set.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

// Gate: must be set to '1' or 'true' via --dart-define or environment.
const _runIntegration =
    bool.fromEnvironment('GENUIFORM_RUN_INTEGRATION', defaultValue: false);

/// Reads the API key from --dart-define first, then from the environment.
String _apiKey() {
  const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
  if (fromDefine.isNotEmpty) return fromDefine;
  return Platform.environment['GEMINI_API_KEY'] ?? '';
}

// ---------------------------------------------------------------------------
// Freelance qualification form config — mirrors example/lib/scenarios/
// ---------------------------------------------------------------------------

FormConfig _freelanceConfig(LlmClient client) {
  return FormConfig(
    contract: Contract(fields: {
      'name': const FieldSpec(type: 'String', required: true),
      'company': const FieldSpec(type: 'String', required: true),
      'pain_point': const FieldSpec(
        type: 'String',
        required: true,
        description: 'The concrete problem they want solved',
      ),
      'timeline': const FieldSpec(
        type: 'String',
        required: true,
        enumValues: ['immediate', '1-3 months', '3-6 months', '6+'],
      ),
      'budget_eur': const FieldSpec(type: 'int', required: false),
      'role': const FieldSpec(
        type: 'String',
        required: false,
        enumValues: ['decision_maker', 'influencer', 'researcher'],
      ),
    }),
    constraints: [
      const NeverCollect(fieldOrTopic: 'payment_info'),
      const NeverCollect(fieldOrTopic: 'personal_id_numbers'),
      const MaxSteps(value: 8),
    ],
    posture: Posture.salesDiscovery(),
    outcomes: Branch(
      id: 'lead_split',
      options: [
        BranchOption(
          id: 'book_call',
          criterion: 'qualified + budget fits + decision-maker',
          contractDelta: null,
          child: Outcome(
            id: 'book_call',
            contractDelta: Contract(fields: {}),
            handoff: null,
          ),
        ),
        BranchOption(
          id: 'send_proposal',
          criterion: 'qualified + needs more info before commit',
          contractDelta: null,
          child: Outcome(
            id: 'send_proposal',
            contractDelta: Contract(fields: {}),
            handoff: null,
          ),
        ),
        BranchOption(
          id: 'decline',
          criterion: 'budget mismatch, scope mismatch, or red flag',
          contractDelta: null,
          child: Outcome(
            id: 'decline',
            contractDelta: Contract(fields: {}),
            handoff: null,
          ),
        ),
      ],
    ),
    client: client,
    model: 'gemini-2.5-flash',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Freelance qualification — end-to-end (real Gemini API)', () {
    test(
      'form reaches a terminal Outcome within MaxSteps(8) with terse input',
      () async {
        if (!_runIntegration) {
          markTestSkipped(
            'Integration tests disabled. '
            'Set --dart-define=GENUIFORM_RUN_INTEGRATION=1 to run.',
          );
          return;
        }

        final apiKey = _apiKey();

        expect(
          apiKey,
          isNotEmpty,
          reason: 'Set GEMINI_API_KEY env var or --dart-define=GEMINI_API_KEY.',
        );

        final client = GeminiApiClient(apiKey: apiKey);

        final config = _freelanceConfig(client);
        final controller = FormController(
          config: config,
          strategy: GenerativeStrategy(),
        );

        // Terse user answers — simulates low engagement to exercise
        // the form's ability to still converge on an Outcome.
        final terseAnswers = [
          'Bob',       // name
          'Acme Ltd',  // company
          'idk',       // pain_point — vague
          '3-6 months', // timeline
          'idk',       // role — vague
          'idk',       // any further question — still terse
          'idk',
          'idk',
        ];

        final completer = Completer<OutcomeReached>();

        controller.events.listen((event) {
          if (event is OutcomeReached && !completer.isCompleted) {
            completer.complete(event);
          }
        });

        await controller.start();

        // Drive form with terse answers in a loop
        for (final answer in terseAnswers) {
          if (completer.isCompleted) break;
          final session = controller.currentSession;
          if (session.status == SessionStatus.completed ||
              session.status == SessionStatus.escalated) {
            break;
          }
          // Wait for current step to be ready
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (controller.currentStep != null) {
            await controller.submitAnswer(answer);
          }
        }

        // Wait for an OutcomeReached event with a 90-second timeout.
        final reached = await completer.future.timeout(
          const Duration(seconds: 90),
          onTimeout: () =>
              throw TimeoutException('Form did not reach Outcome in 90s'),
        );

        await controller.dispose();

        expect(reached.outcome.id, isNotEmpty);
        expect(
          controller.currentSession.history.length,
          lessThanOrEqualTo(8),
          reason: 'MaxSteps(8) must not be exceeded',
        );
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
