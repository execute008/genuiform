import 'constraints.dart';
import 'form_result.dart';
import 'outcomes.dart';
import 'quiz_step_spec.dart';

/// Transient runtime events emitted by a [Strategy] on its output stream.
///
/// [StepEvent] is **not JSON-serialised** — these events are consumed in
/// real-time by the `GenuiForm` widget and the runtime loop. They are never
/// persisted.
///
/// Use Dart's `switch` expression or `when`/`map` (if using freezed utilities)
/// to handle each variant:
///
/// ```dart
/// strategy.nextStep(session, config).listen((event) {
///   switch (event) {
///     case StepReady(:final spec):
///       renderStep(spec);
///     case LayerComplete(:final layer, :final offerExit):
///       if (offerExit) showExitPrompt(layer);
///     case OutcomeReached(:final outcome, :final result):
///       outcome.handoff?.call(result);
///     // ...
///   }
/// });
/// ```
sealed class StepEvent {
  const StepEvent();
}

/// The LLM has produced the next step to show the user.
class StepReady extends StepEvent {
  const StepReady({required this.spec});

  /// The step specification to render.
  final QuizStepSpec spec;

  @override
  String toString() => 'StepReady(spec: $spec)';
}

/// The running contract for the current [Layer] is fully satisfied — the
/// runtime is offering the user a graceful exit.
///
/// If [offerExit] is `true`, the `GenuiForm` widget should show an exit
/// prompt alongside a "keep going" affordance. If `false`, the form
/// automatically continues into the next [Layer].
class LayerComplete extends StepEvent {
  const LayerComplete({required this.layer, required this.offerExit});

  /// The [Layer] whose contract has just been filled.
  final Layer layer;

  /// Whether to present an explicit exit prompt to the user.
  final bool offerExit;

  @override
  String toString() =>
      'LayerComplete(layer: ${layer.id}, offerExit: $offerExit)';
}

/// The LLM has resolved a [Branch], choosing one of its options.
///
/// The runtime uses [branchId] and [optionId] to update
/// [Session.composeRunningContract] and route the session into the chosen
/// option's child node.
class BranchTaken extends StepEvent {
  const BranchTaken({required this.branchId, required this.optionId});

  /// The ID of the [Branch] node that was resolved.
  final String branchId;

  /// The ID of the [BranchOption] chosen by the LLM.
  final String optionId;

  @override
  String toString() =>
      'BranchTaken(branchId: $branchId, optionId: $optionId)';
}

/// The form has reached a terminal [Outcome] and all required contract fields
/// are satisfied.
///
/// The runtime will call [Outcome.handoff] (if non-null) with [result].
class OutcomeReached extends StepEvent {
  const OutcomeReached({required this.outcome, required this.result});

  /// The terminal [Outcome] node that was reached.
  final Outcome outcome;

  /// The collected [FormResult] at the moment of completion.
  final FormResult result;

  @override
  String toString() =>
      'OutcomeReached(outcome: ${outcome.id}, status: ${result.status})';
}

/// An [EscalateIf] constraint fired — the form transfers control to the
/// constraint's [EscalationHandler].
class EscalationFired extends StepEvent {
  const EscalationFired({required this.rule});

  /// The constraint that triggered the escalation.
  final EscalateIf rule;

  @override
  String toString() => 'EscalationFired(trigger: ${rule.trigger})';
}

/// An unrecoverable error occurred in the strategy's LLM call or runtime.
///
/// The `GenuiForm` widget should display an error state and offer a retry.
class StreamError extends StepEvent {
  const StreamError({required this.error});

  /// The underlying error or exception.
  final Object error;

  @override
  String toString() => 'StreamError(error: $error)';
}
