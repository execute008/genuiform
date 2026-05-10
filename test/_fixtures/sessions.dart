// ignore_for_file: avoid_dynamic_calls

import 'package:genuiform/genuiform.dart';

// ────────────────────────────────────────────────────────────────────────────
// Shared field specs
// ────────────────────────────────────────────────────────────────────────────

const _emailField = FieldSpec(type: 'String', required: true);
const _nameField = FieldSpec(type: 'String', required: true);
const _goalsField = FieldSpec(type: 'List', required: true);
const _fitnessLevelField = FieldSpec(type: 'String', required: true);
const _equipmentField = FieldSpec(type: 'List', required: true);
const _limitationsField = FieldSpec(type: 'List', required: true);
const _preferredDaysField = FieldSpec(type: 'List', required: true);
const _workoutMinutesField = FieldSpec(type: 'int', required: true);
const _heightCmField = FieldSpec(type: 'int', required: true);
const _weightKgField = FieldSpec(type: 'int', required: true);
const _dietaryRestrictionsField = FieldSpec(type: 'List', required: true);
const _mealPreferencesField = FieldSpec(type: 'String', required: false);
const _allergiesField = FieldSpec(type: 'List', required: false);
const _mealsPerDayField = FieldSpec(type: 'int', required: true);
const _proteinTargetField = FieldSpec(type: 'int', required: true);
const _caloireCeilingField = FieldSpec(type: 'int', required: false);

// ────────────────────────────────────────────────────────────────────────────
// gymgeistTree — mirrors spec §11.2
// ────────────────────────────────────────────────────────────────────────────

/// Builds the GymGeist outcome tree from spec §11.2.
///
/// Structure:
///   Layer('account_only')
///     → Layer('with_workout_plan')
///       → Branch('nutrition_path', [
///           BranchOption('with_meal_plan', contractDelta: mealContract),
///           BranchOption('with_macros_only', contractDelta: macroContract),
///           BranchOption('skip_nutrition', contractDelta: null),
///         ])
///
/// This tree exercises Layer + Branch + nullable contractDelta all at once.
/// Reused across ConstraintEnforcer, OutcomeNavigator, and strategy tests.
OutcomeNode gymgeistTree() {
  final mealOutcome = Outcome(
    id: 'full_meal_plan',
    contractDelta: Contract(fields: {}),
    handoff: null,
  );

  final macroOutcome = Outcome(
    id: 'full_macros',
    contractDelta: Contract(fields: {}),
    handoff: null,
  );

  final workoutOnlyOutcome = Outcome(
    id: 'workout_only',
    contractDelta: Contract(fields: {}),
    handoff: null,
  );

  final nutritionBranch = Branch(
    id: 'nutrition_path',
    options: [
      BranchOption(
        id: 'with_meal_plan',
        criterion: 'user wants concrete meals planned',
        contractDelta: Contract(fields: {
          'dietary_restrictions': _dietaryRestrictionsField,
          'meal_preferences': _mealPreferencesField,
          'allergies': _allergiesField,
          'meals_per_day': _mealsPerDayField,
        }),
        child: mealOutcome,
      ),
      BranchOption(
        id: 'with_macros_only',
        criterion: 'user wants macro targets, will plan own meals',
        contractDelta: Contract(fields: {
          'protein_target_g': _proteinTargetField,
          'calorie_ceiling': _caloireCeilingField,
        }),
        child: macroOutcome,
      ),
      BranchOption(
        id: 'skip_nutrition',
        criterion: 'user opts out of nutrition entirely',
        contractDelta: null, // nullable per spec v0.4 Fix A
        child: workoutOnlyOutcome,
      ),
    ],
  );

  final withWorkoutPlan = Layer(
    id: 'with_workout_plan',
    contractDelta: Contract(fields: {
      'goals': _goalsField,
      'fitness_level': _fitnessLevelField,
      'equipment': _equipmentField,
      'limitations': _limitationsField,
      'preferred_days': _preferredDaysField,
      'workout_minutes': _workoutMinutesField,
      'height_cm': _heightCmField,
      'weight_kg': _weightKgField,
    }),
    handoff: null,
    next: nutritionBranch,
  );

  return Layer(
    id: 'account_only',
    contractDelta: Contract(fields: {
      'email': _emailField,
      'name': _nameField,
    }),
    handoff: null,
    next: withWorkoutPlan,
  );
}

// ────────────────────────────────────────────────────────────────────────────
// sampleContract — convenience builder
// ────────────────────────────────────────────────────────────────────────────

/// Builds a [Contract] with the given fields merged on top of a baseline
/// that has two optional fields.
Contract sampleContract({Map<String, FieldSpec>? fields}) {
  return Contract(
    fields: fields ??
        {
          'name': _nameField,
          'email': _emailField,
        },
  );
}

// ────────────────────────────────────────────────────────────────────────────
// sampleSession — convenience builder
// ────────────────────────────────────────────────────────────────────────────

/// Builds a [Session] with sensible defaults, suitable for unit tests.
///
/// - [answers]: merged into the flat answers map.
/// - [currentNode]: defaults to a simple Outcome.
/// - [history]: defaults to empty.
Session sampleSession({
  Map<String, dynamic>? answers,
  OutcomeNode? currentNode,
  List<Answer>? history,
}) {
  final node = currentNode ??
      Outcome(
        id: 'default_outcome',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );

  final resolvedAnswers = answers ?? {};

  return Session(
    currentNode: node,
    history: history ?? [],
    answers: resolvedAnswers,
    runningContract: Contract(fields: {}),
    status: SessionStatus.active,
    lastSignal: EngagementSignal.weak,
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Helper: build a minimal QuizStepSpec for tests
// ────────────────────────────────────────────────────────────────────────────

/// Builds a minimal [QuizStepSpec] for use in test assertions.
QuizStepSpec sampleStep({
  String id = 'test_step',
  String title = 'Test question',
  QuizInputType inputType = QuizInputType.text,
  String? description,
  List<QuizChoice>? choices,
}) {
  return QuizStepSpec(
    id: id,
    title: title,
    inputType: inputType,
    description: description,
    choices: choices,
  );
}

/// Builds a minimal [Answer] for use in test assertions.
Answer sampleAnswer({
  String stepId = 'test_step',
  QuizStepSpec? stepSpec,
  dynamic answer = 'some answer',
  EngagementSignal engagement = EngagementSignal.weak,
  DateTime? timestamp,
}) {
  return Answer(
    stepId: stepId,
    stepSpec: stepSpec ?? sampleStep(id: stepId),
    answer: answer,
    timestamp: timestamp ?? DateTime(2026, 5, 5, 12),
    engagement: engagement,
  );
}
