import 'package:flutter/foundation.dart';
import 'package:genuiform/genuiform.dart';

// ---------------------------------------------------------------------------
// GymGeist onboarding — spec §11.2
//
// Full ladder + branch tree with nutrition split.
// Uses Posture.supportiveOnboarding().
//
// ### Structure
//
//   Layer('account_only')            — email + name only; minimal onboarding
//     └─ Layer('with_workout_plan')  — adds 8 fitness fields
//          └─ Branch('nutrition_path')
//               ├─ BranchOption('with_meal_plan')
//               │    └─ Outcome('full_meal_plan')
//               ├─ BranchOption('with_macros_only')
//               │    └─ Outcome('full_macros')
//               └─ BranchOption('skip_nutrition')
//                    └─ Outcome('workout_only')
//
// ---------------------------------------------------------------------------

/// Builds the GymGeist onboarding [GenuiForm] per spec §11.2.
///
/// [showFeedback] is invoked by each [Handoff] and escalation handler.
///
/// ### Divergences from spec §11.2 pseudo-Dart
///
/// - `FieldSpec(type: List, ...)` → `FieldSpec(type: 'List', ...)`.
/// - `FieldSpec(type: String, ...)` → `FieldSpec(type: 'String', ...)`.
/// - `FieldSpec(type: int, ...)` → `FieldSpec(type: 'int', ...)`.
/// - `Layer('account_only', contractDelta: ..., handoff: ..., next: ...)` →
///   `Layer(id: 'account_only', contractDelta: ..., handoff: ..., next: ...)`.
/// - `Branch('nutrition_path', options: [...])` →
///   `Branch(id: 'nutrition_path', options: [...])`.
/// - `BranchOption('with_meal_plan', criterion: ..., contractDelta: ..., child: ...)` →
///   `BranchOption(id: 'with_meal_plan', criterion: ..., contractDelta: ..., child: ...)`.
/// - `Handoff(onReached: fn)` → direct `void Function(dynamic)` closure.
/// - `EscalateIf('...', handler: ReferToProfessionalSupport())` →
///   `EscalateIf(trigger: '...', handler: (result) => showFeedback(...))`.
/// - `NeverSkip(['height_cm', 'weight_kg'])` → `NeverSkip(fieldIds: ['height_cm', 'weight_kg'])`.
/// - `MaxSteps(20)` → `MaxSteps(value: 20)`.
/// - `StopIf('user is under 16')` → `StopIf(trigger: 'user is under 16')`.
/// - `Layer.contractDelta` for `account_only` holds only `email` and `name`.
///   The spec shows `Contract(fields: {/* email, name only */})` as a comment;
///   here it is expanded to the literal two fields.
GenuiForm gymgeistOnboardingForm({
  required LlmClient client,
  required String model,
  required void Function(String message) showFeedback,
}) {
  return GenuiForm(
    // ── Contract (root — email + name only) ─────────────────────────────────
    contract: Contract(fields: {
      'email': const FieldSpec(type: 'String', required: true),
      'name': const FieldSpec(type: 'String', required: true),
    }),

    // ── Constraints ─────────────────────────────────────────────────────────
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

    // ── Posture ─────────────────────────────────────────────────────────────
    posture: Posture.supportiveOnboarding(),

    // ── Outcome tree ─────────────────────────────────────────────────────────
    //
    // Layer: account_only
    //   └─ Layer: with_workout_plan
    //        └─ Branch: nutrition_path
    //             ├─ with_meal_plan  → Outcome: full_meal_plan
    //             ├─ with_macros_only → Outcome: full_macros
    //             └─ skip_nutrition  → Outcome: workout_only
    outcomes: Layer(
      id: 'account_only',
      contractDelta: Contract(fields: {
        'email': const FieldSpec(type: 'String', required: true),
        'name': const FieldSpec(type: 'String', required: true),
      }),
      handoff: (result) {
        debugPrint('[gymgeist] handoff: account_only — $result');
        showFeedback('Welcome! Your account is ready (minimal setup).');
      },
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
        handoff: (result) {
          debugPrint('[gymgeist] handoff: with_workout_plan — $result');
          showFeedback('Workout plan generated! Enter the app.');
        },
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
                handoff: (result) {
                  debugPrint('[gymgeist] handoff: full_meal_plan — $result');
                  showFeedback(
                    'Full setup complete — workout plan + meal plan ready!',
                  );
                },
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
                handoff: (result) {
                  debugPrint('[gymgeist] handoff: full_macros — $result');
                  showFeedback(
                    'Full setup complete — workout plan + macro targets ready!',
                  );
                },
              ),
            ),
            BranchOption(
              id: 'skip_nutrition',
              criterion: 'user opts out of nutrition entirely',
              contractDelta: null, // no extra fields collected
              child: Outcome(
                id: 'workout_only',
                contractDelta: Contract(fields: {}),
                handoff: (result) {
                  debugPrint('[gymgeist] handoff: workout_only — $result');
                  showFeedback('Workout-only setup complete. Skip nutrition any time.');
                },
              ),
            ),
          ],
        ),
      ),
    ),

    // ── Client & model ───────────────────────────────────────────────────────
    client: client,
    model: model,

    // ── Lifecycle callbacks ──────────────────────────────────────────────────
    onComplete: (result) {
      // Outcome.handoff has already fired with context-specific feedback.
    },
    onEscalation: (rule) {
      showFeedback('Session ended: ${rule.trigger}');
    },
  );
}
