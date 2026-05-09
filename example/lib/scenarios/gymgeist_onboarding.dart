import 'package:genuiform/genuiform.dart';
import 'package:genuiform_a2ui/genuiform_a2ui.dart';

import 'freelance_qualification.dart' show ScenarioSpec;

// ---------------------------------------------------------------------------
// GymGeist onboarding — spec §11.2
//
// Layer('account_only')
//   └─ Layer('with_workout_plan')
//        └─ Branch('nutrition_path')
//             ├─ with_meal_plan   → Outcome('full_meal_plan')
//             ├─ with_macros_only → Outcome('full_macros')
//             └─ skip_nutrition   → Outcome('workout_only')
// ---------------------------------------------------------------------------

/// Builds the GymGeist onboarding [ScenarioSpec] per spec §11.2.
///
/// `Layer.handoff` and `Outcome.handoff` are `null` — the owning
/// [ScenarioPage] resolves `result.reachedOutcome?.id` and renders SnackBar
/// or A2UI accordingly. Note: only terminal outcomes are mapped in
/// [handoffMap]; intermediate `Layer` ids (`account_only`,
/// `with_workout_plan`) only fire when the form completes early at that
/// layer, so they get their own entries.
ScenarioSpec gymgeistOnboardingSpec({
  required void Function(String message) showFeedback,
}) {
  return (
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
        handler: (result) =>
            showFeedback('Please speak with a registered dietitian or your GP.'),
      ),
      EscalateIf(
        trigger: 'injury during exercise',
        handler: (result) =>
            showFeedback('Please seek medical advice before continuing.'),
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
          'workout_minutes': const FieldSpec(
            type: 'int',
            required: true,
            range: NumRange(min: 15, max: 240),
          ),
          'height_cm': const FieldSpec(
            type: 'int',
            required: true,
            range: NumRange(min: 100, max: 250),
          ),
          'weight_kg': const FieldSpec(
            type: 'int',
            required: true,
            range: NumRange(min: 30, max: 300),
          ),
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
                  enumValues: [
                    'vegetarian',
                    'vegan',
                    'pescatarian',
                    'omnivore',
                    'keto',
                    'paleo',
                  ],
                ),
                'meal_preferences': const FieldSpec(
                  type: 'String',
                  required: false,
                  description:
                      'Free-text notes on meal style, cuisines, dislikes',
                ),
                'allergies': const FieldSpec(type: 'List', required: false),
                'meals_per_day': const FieldSpec(
                  type: 'int',
                  required: true,
                  range: NumRange(min: 2, max: 6),
                ),
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
                  range: NumRange(min: 40, max: 400),
                ),
                'calorie_ceiling': const FieldSpec(
                  type: 'int',
                  required: false,
                  range: NumRange(min: 1200, max: 5000),
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
    handoffMap: const {
      'account_only': SimulatedHandoff(
        label: 'Welcome — account ready (minimal setup)',
        icon: 'person_add',
      ),
      'with_workout_plan': SimulatedHandoff(
        label: 'Workout plan generated — enter the app',
        icon: 'fitness_center',
      ),
      'full_meal_plan': SimulatedHandoff(
        label: 'Full setup — workout + meal plan ready',
        icon: 'restaurant_menu',
      ),
      'full_macros': SimulatedHandoff(
        label: 'Full setup — workout + macro targets ready',
        icon: 'calculate',
      ),
      'workout_only': SimulatedHandoff(
        label: 'Workout-only setup complete',
        icon: 'check_circle',
      ),
    },
  );
}
