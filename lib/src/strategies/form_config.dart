// Pure Dart — no Flutter imports.

import 'package:equatable/equatable.dart';

import '../llm/llm_client.dart';
import '../models/constraints.dart';
import '../models/contract.dart';
import '../models/outcomes.dart';
import '../models/posture.dart';
import '../models/quiz_step_spec.dart';

// Sentinel used by FormConfig.copyWith to distinguish "not provided" from
// "explicitly set to null" for the nullable cachedContent parameter.
const _clearCachedContent = Object();

/// Frozen configuration object for a form session.
///
/// [FormConfig] bundles all four primitives (contract, constraints, posture,
/// outcomes) with the LLM client and model string. It is passed unchanged to
/// [Strategy.nextStep] on every turn.
///
/// ### Equality
///
/// Uses [EquatableMixin]. The [client] field is deliberately **excluded** from
/// equality — clients are stateful (they hold connections, auth tokens, etc.)
/// and should never be compared by identity. [cachedContent] is also excluded
/// — it is a runtime artefact that varies independently of the logical config.
class FormConfig with EquatableMixin {
  const FormConfig({
    required this.contract,
    required this.constraints,
    required this.posture,
    required this.outcomes,
    required this.client,
    required this.model,
    this.temperature = 0.7,
    this.guidedCatalog,
    this.cachedContent,
  });

  /// The fields this form must collect for completion.
  final Contract contract;

  /// Hard invariants checked every turn by [ConstraintEnforcer].
  final List<Constraint> constraints;

  /// Soft behavioural knobs interpreted by the LLM.
  final Posture posture;

  /// The outcome tree — where the form can end up.
  final OutcomeNode outcomes;

  /// The LLM transport used for step generation.
  ///
  /// Excluded from equality — clients have side effects.
  final LlmClient client;

  /// The Vertex AI model ID string (e.g. `'gemini-2.5-flash'`).
  final String model;

  /// Sampling temperature for LLM generation. Defaults to `0.7`.
  final double temperature;

  /// Step catalog for [GuidedStrategy].
  ///
  /// When non-null, [GuidedStrategy] restricts the LLM to picking a step ID
  /// from this list instead of generating the full step JSON.
  final List<QuizStepSpec>? guidedCatalog;

  /// Resource name of an active Gemini cached content entry, e.g.
  /// `'cachedContents/abc123'`. When non-null, [GenerativeStrategy] passes it
  /// through to [LlmClient.generate] so the system instruction is served from
  /// the cache rather than re-sent on every turn.
  ///
  /// Excluded from equality — it is a runtime artefact managed by
  /// [FormController], not part of the logical configuration.
  final String? cachedContent;

  @override
  List<Object?> get props => [
        contract,
        constraints,
        posture,
        outcomes,
        model,
        temperature,
        guidedCatalog,
      ];

  /// Returns a copy with selected fields replaced.
  ///
  /// To explicitly clear [cachedContent] to null, pass
  /// `cachedContent: null` — the sentinel [_clearCachedContent] is used
  /// internally to distinguish "not provided" from "clear to null".
  FormConfig copyWith({
    Contract? contract,
    List<Constraint>? constraints,
    Posture? posture,
    OutcomeNode? outcomes,
    LlmClient? client,
    String? model,
    double? temperature,
    List<QuizStepSpec>? guidedCatalog,
    Object? cachedContent = _clearCachedContent,
  }) {
    return FormConfig(
      contract: contract ?? this.contract,
      constraints: constraints ?? this.constraints,
      posture: posture ?? this.posture,
      outcomes: outcomes ?? this.outcomes,
      client: client ?? this.client,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      guidedCatalog: guidedCatalog ?? this.guidedCatalog,
      cachedContent: identical(cachedContent, _clearCachedContent)
          ? this.cachedContent
          : cachedContent as String?,
    );
  }

  @override
  String toString() =>
      'FormConfig(model: $model, temperature: $temperature, '
      'constraints: ${constraints.length}, '
      'guidedCatalog: ${guidedCatalog?.length}, '
      'cachedContent: $cachedContent)';
}
