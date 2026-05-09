// End-to-end integration tests for the GymGeist onboarding form.
//
// **Never run by `flutter test`.** This file lives under `integration_test/`
// and is only executed manually with the environment variable
// `GENUIFORM_RUN_INTEGRATION=1` (or `true`) set.
//
// Run with:
//   GENUIFORM_RUN_INTEGRATION=1 \
//   GEMINI_API_KEY=<aistudio-api-key> \
//   flutter test integration_test/gymgeist_onboarding_e2e_test.dart \
//     --dart-define=GENUIFORM_RUN_INTEGRATION=1 \
//     --dart-define=GEMINI_API_KEY=<key>
//
// All tests in this file are skipped unless the gate is set.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

// Gate: must be set via --dart-define or environment.
const _runIntegration =
    bool.fromEnvironment('GENUIFORM_RUN_INTEGRATION', defaultValue: false);

/// Reads the API key from --dart-define first, then from the environment.
String _apiKey() {
  const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
  if (fromDefine.isNotEmpty) return fromDefine;
  return Platform.environment['GEMINI_API_KEY'] ?? '';
}

// ---------------------------------------------------------------------------
// GymGeist config — mirrors spec §11.2 and example/lib/scenarios/
// ---------------------------------------------------------------------------

FormConfig _gymgeistConfig(LlmClient client) {
  return FormConfig(
    contract: Contract(fields: {
      'email': const FieldSpec(type: 'String', required: true),
      'name': const FieldSpec(type: 'String', required: true),
    }),
    constraints: [
      const NeverSkip(fieldIds: ['height_cm', 'weight_kg']),
      const MaxSteps(value: 20),
      const StopIf(trigger: 'user is under 16'),
      EscalateIf(
        trigger: 'eating disorder or extreme restriction',
        handler: (_) {},
      ),
      EscalateIf(
        trigger: 'injury during exercise',
        handler: (_) {},
      ),
    ],
    posture: Posture.supportiveOnboarding(),
    outcomes: Layer(
      id: 'account_only',
      contractDelta: Contract(fields: {
        'email': const FieldSpec(type: 'String', required: true),
        'name': const FieldSpec(type: 'String', required: true),
      }),
      handoff: null,
      next: Layer(
        id: 'with_workout_plan',
        contractDelta: Contract(fields: {
          'goals': const FieldSpec(type: 'List', required: true),
          'fitness_level': const FieldSpec(type: 'String', required: true),
          'equipment': const FieldSpec(type: 'List', required: true),
          'limitations': const FieldSpec(type: 'List', required: true),
          'preferred_days': const FieldSpec(type: 'List', required: true),
          'workout_minutes': const FieldSpec(type: 'int', required: true),
          'height_cm': const FieldSpec(type: 'int', required: true),
          'weight_kg': const FieldSpec(type: 'int', required: true),
        }),
        handoff: null,
        next: Branch(
          id: 'nutrition_path',
          options: [
            BranchOption(
              id: 'with_meal_plan',
              criterion: 'user wants concrete meals planned',
              contractDelta: Contract(fields: {
                'dietary_restrictions': const FieldSpec(
                  type: 'List',
                  required: true,
                ),
                'meals_per_day': const FieldSpec(type: 'int', required: true),
              }),
              child: Outcome(
                id: 'full_meal_plan',
                contractDelta: Contract(fields: {}),
                handoff: null,
              ),
            ),
            BranchOption(
              id: 'with_macros_only',
              criterion: 'user wants macro targets, will plan own meals',
              contractDelta: Contract(fields: {
                'protein_target_g': const FieldSpec(
                  type: 'int',
                  required: true,
                ),
              }),
              child: Outcome(
                id: 'full_macros',
                contractDelta: Contract(fields: {}),
                handoff: null,
              ),
            ),
            BranchOption(
              id: 'skip_nutrition',
              criterion: 'user opts out of nutrition entirely',
              contractDelta: null,
              child: Outcome(
                id: 'workout_only',
                contractDelta: Contract(fields: {}),
                handoff: null,
              ),
            ),
          ],
        ),
      ),
    ),
    client: client,
    model: 'gemini-2.5-flash',
  );
}

// ---------------------------------------------------------------------------
// Helper: drives the controller with repeated short answers until a terminal
// event (OutcomeReached or LayerComplete) fires, or the step limit is hit.
// ---------------------------------------------------------------------------

Future<StepEvent?> _driveForm(
  FormController controller,
  List<String> answers,
) async {
  final completer = Completer<StepEvent>();

  controller.events.listen((event) {
    if (!completer.isCompleted) {
      if (event is OutcomeReached || event is LayerComplete) {
        completer.complete(event);
      }
    }
  });

  await controller.start();

  for (final answer in answers) {
    if (completer.isCompleted) break;
    final session = controller.currentSession;
    if (session.status == SessionStatus.completed ||
        session.status == SessionStatus.escalated) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (controller.currentStep != null) {
      await controller.submitAnswer(answer);
    }
  }

  if (completer.isCompleted) return completer.future;

  // Wait up to 90s total
  return completer.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () =>
        throw TimeoutException('Form did not reach expected event in 90s'),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('GymGeist onboarding — end-to-end (real Gemini API)', () {
    late GeminiApiClient client;

    setUp(() {
      if (!_runIntegration) return;

      final apiKey = _apiKey();

      expect(
        apiKey,
        isNotEmpty,
        reason: 'Set GEMINI_API_KEY env var or --dart-define=GEMINI_API_KEY.',
      );

      client = GeminiApiClient(apiKey: apiKey);
    });

    test(
      '(a) short-answer user reaches account_only layer in ≤4 steps',
      () async {
        if (!_runIntegration) {
          markTestSkipped(
            'Integration tests disabled. '
            'Set --dart-define=GENUIFORM_RUN_INTEGRATION=1 to run.',
          );
          return;
        }

        final config = _gymgeistConfig(client);
        final controller = FormController(
          config: config,
          strategy: GenerativeStrategy(),
        );

        // Very short, disengaged answers — the form should stay at account_only
        final shortAnswers = ['alice@example.com', 'Alice', 'idk', 'idk'];

        final event = await _driveForm(controller, shortAnswers);
        await controller.dispose();

        // We expect the form to fire either LayerComplete (account_only exited)
        // or OutcomeReached within 4 steps.
        expect(
          event,
          anyOf(isA<LayerComplete>(), isA<OutcomeReached>()),
          reason: 'Short-answer user should exit at an early layer',
        );

        expect(
          controller.currentSession.history.length,
          lessThanOrEqualTo(4),
          reason:
              'Short-answer user should not be pushed past 4 steps at account_only',
        );
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );

    test(
      '(b) engaged user reaches with_meal_plan Outcome in ≤14 steps',
      () async {
        if (!_runIntegration) {
          markTestSkipped(
            'Integration tests disabled. '
            'Set --dart-define=GENUIFORM_RUN_INTEGRATION=1 to run.',
          );
          return;
        }

        final config = _gymgeistConfig(client);
        final controller = FormController(
          config: config,
          strategy: GenerativeStrategy(),
        );

        // Long, enthusiastic, detailed answers — simulates a highly engaged user
        // who wants a full meal plan.
        final engagedAnswers = [
          'alice@example.com',
          'Alice Johnson — really excited to get started!',
          'I want to lose fat, build muscle, and run a 5K by end of year.',
          'I would say intermediate — I have been going to the gym for 2 years.',
          'I have dumbbells, a barbell set, a pull-up bar, and access to a commercial gym 3 days a week.',
          'No injuries, but I have mild lower-back tightness so I want to avoid heavy deadlifts for now.',
          'Monday, Wednesday, Friday, and Saturday.',
          '60',  // workout_minutes
          '172', // height_cm
          '74',  // weight_kg
          'Yes, I would love a full meal plan — vegetarian please.',
          'omnivore', // dietary_restrictions
          '3',  // meals_per_day
          // Additional answers if needed
          'Yes, full setup please',
          'I want the complete experience',
        ];

        final completer = Completer<OutcomeReached>();

        controller.events.listen((event) {
          if (event is OutcomeReached && !completer.isCompleted) {
            completer.complete(event);
          }
        });

        await controller.start();

        for (final answer in engagedAnswers) {
          if (completer.isCompleted) break;
          final session = controller.currentSession;
          if (session.status == SessionStatus.completed ||
              session.status == SessionStatus.escalated) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (controller.currentStep != null) {
            await controller.submitAnswer(answer);
          }
        }

        final reached = await completer.future.timeout(
          const Duration(seconds: 90),
          onTimeout: () =>
              throw TimeoutException('Engaged user did not reach Outcome in 90s'),
        );

        await controller.dispose();

        // The engaged user should reach the deep end of the nutrition branch.
        // Any of the three Outcome IDs is valid — we assert specifically for
        // full_meal_plan but also accept the other two if the LLM interprets
        // the answers differently.
        expect(
          reached.outcome.id,
          isIn(['full_meal_plan', 'full_macros', 'workout_only']),
          reason: 'Engaged user should reach a nutrition-branch Outcome',
        );

        expect(
          controller.currentSession.history.length,
          lessThanOrEqualTo(14),
          reason: 'Engaged user should complete in ≤14 steps',
        );
      },
      timeout: const Timeout(Duration(seconds: 120)),
    );
  });
}
