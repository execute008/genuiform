// Pure Dart — no Flutter imports.

import '../models/answer.dart';
import '../models/constraints.dart';
import '../models/quiz_input_type.dart';
import '../models/quiz_step_spec.dart';
import '../models/session.dart';

// ────────────────────────────────────────────────────────────────────────────
// EnforcementResult sealed family
// ────────────────────────────────────────────────────────────────────────────

/// The result of running a [Constraint] check against a step or answer.
///
/// The sealed family has four variants:
/// - [Allowed] — no constraint fired; the step or answer is permitted.
/// - [Replaced] — a constraint replaced the step with a safer alternative.
/// - [Stop] — a constraint halted the form entirely.
/// - [Escalated] — an [EscalateIf] constraint fired; the caller must invoke
///   [EscalateIf.handler].
sealed class EnforcementResult {
  const EnforcementResult();
}

/// The step or answer passed all constraint checks; nothing was overridden.
class Allowed extends EnforcementResult {
  const Allowed();
}

/// A constraint replaced the proposed step with [replacement].
///
/// Typical replacements are `noneJustInformation` steps that skip collection
/// (for [NeverCollect]) or prompt for consent (for [RequireConsent]).
class Replaced extends EnforcementResult {
  /// The replacement step to show instead of the LLM-proposed one.
  final QuizStepSpec replacement;

  const Replaced(this.replacement);
}

/// A constraint stopped the form entirely.
class Stop extends EnforcementResult {
  /// Human-readable explanation of why the form was stopped.
  final String reason;

  const Stop(this.reason);
}

/// An [EscalateIf] constraint fired.
///
/// The caller (typically the Strategy) is responsible for invoking
/// [rule.handler] with the current [FormResult]. This separation lets the
/// runtime remain side-effect-free.
class Escalated extends EnforcementResult {
  /// The constraint that fired.
  final EscalateIf rule;

  const Escalated(this.rule);
}

// ────────────────────────────────────────────────────────────────────────────
// ConstraintEnforcer
// ────────────────────────────────────────────────────────────────────────────

/// Checks every LLM-emitted step and every user answer against the active
/// [Constraint] list, overriding violations before they reach the UI or the
/// session state.
///
/// ### Trigger matching
///
/// All trigger matching is **case-insensitive substring** for v1. This is
/// intentionally conservative — a single word in the wrong context will fire
/// the constraint. Future versions may support regex or embedding-based
/// similarity for more nuanced matching.
///
/// ### Iteration order
///
/// Constraints are checked in the order supplied to the constructor.
/// Iteration **short-circuits** on the first non-[Allowed] result — the
/// remainder of the list is not evaluated.
///
/// ### Responsibility split
///
/// [ConstraintEnforcer] is a pure query object — it reads from [Session] but
/// never writes to it. The Strategy or FormController is responsible for
/// acting on the returned [EnforcementResult] (e.g. calling
/// [EscalateIf.handler], transitioning [SessionStatus], etc.).
class ConstraintEnforcer {
  /// Creates an enforcer with the given list of constraints.
  ///
  /// Order matters: constraints are evaluated in insertion order and the first
  /// non-[Allowed] result short-circuits further evaluation.
  ConstraintEnforcer(this._constraints);

  final List<Constraint> _constraints;

  // ── Step inspection ───────────────────────────────────────────────────────

  /// Checks [step] against every applicable constraint before rendering it.
  ///
  /// Returns [Allowed] if no constraint fires, [Replaced] if a constraint
  /// substitutes a safer step, or [Stop] if the form must halt.
  EnforcementResult check(QuizStepSpec step, Session session) {
    for (final constraint in _constraints) {
      final result = _checkOne(constraint, step, session);
      if (result is! Allowed) return result;
    }
    return const Allowed();
  }

  EnforcementResult _checkOne(
    Constraint constraint,
    QuizStepSpec step,
    Session session,
  ) {
    return switch (constraint) {
      // ── NeverCollect ──────────────────────────────────────────────────────
      // Case-insensitive substring match against step.id, step.title, and
      // step.description. On match, replaces with a skip step.
      NeverCollect(:final fieldOrTopic) => _checkNeverCollect(
          fieldOrTopic: fieldOrTopic,
          step: step,
        ),

      // ── MaxSteps ──────────────────────────────────────────────────────────
      // Fires Stop when history.length >= max.
      MaxSteps(:final value) => session.history.length >= value
          ? Stop('MaxSteps reached: $value')
          : const Allowed(),

      // ── WhitelistChoices ──────────────────────────────────────────────────
      // Filters choices when step.id matches fieldId and any choice.id is
      // not in the allowed set.
      WhitelistChoices(:final fieldId, :final allowed) =>
        _checkWhitelistChoices(
          fieldId: fieldId,
          allowed: allowed,
          step: step,
        ),

      // ── RequireConsent ────────────────────────────────────────────────────
      // Checks session.answers['__consents'] for the topic. Returns Replaced
      // with a consent-prompt step if the topic has not yet been consented to.
      RequireConsent(:final topic) => _checkRequireConsent(
          topic: topic,
          session: session,
        ),

      // ── NeverSkip — does not block individual steps ───────────────────────
      // Completion is enforced via canComplete(); individual step checks pass.
      NeverSkip() => const Allowed(),

      // ── MinSteps — does not block individual steps ────────────────────────
      // Early-completion prevention is exposed via isAboveMinimum().
      MinSteps() => const Allowed(),

      // ── EscalateIf / StopIf — answer-only constraints ────────────────────
      // These only fire in inspectAnswer, not during step checks.
      EscalateIf() => const Allowed(),
      StopIf() => const Allowed(),
    };
  }

  EnforcementResult _checkNeverCollect({
    required String fieldOrTopic,
    required QuizStepSpec step,
  }) {
    final needle = fieldOrTopic.toLowerCase();
    final idMatch = step.id.toLowerCase().contains(needle);
    final titleMatch = step.title.toLowerCase().contains(needle);
    final descMatch =
        step.description?.toLowerCase().contains(needle) ?? false;

    if (idMatch || titleMatch || descMatch) {
      return Replaced(_neverCollectSkipStep(step.id));
    }
    return const Allowed();
  }

  EnforcementResult _checkWhitelistChoices({
    required String fieldId,
    required List<dynamic> allowed,
    required QuizStepSpec step,
  }) {
    if (step.id != fieldId) return const Allowed();
    if (step.choices == null) return const Allowed();

    final allowedSet = allowed.map((e) => e.toString()).toSet();
    final filtered =
        step.choices!.where((c) => allowedSet.contains(c.id)).toList();

    // All choices are already whitelisted — nothing to replace
    if (filtered.length == step.choices!.length) return const Allowed();

    return Replaced(step.copyWith(choices: filtered));
  }

  EnforcementResult _checkRequireConsent({
    required String topic,
    required Session session,
  }) {
    final consents = session.answers['__consents'];
    if (consents is List && consents.contains(topic)) {
      return const Allowed();
    }
    // Topic not yet consented — replace with consent-prompt step
    return Replaced(_consentPromptStep(topic));
  }

  // ── Answer inspection ─────────────────────────────────────────────────────

  /// Checks [answer] against every applicable constraint after the user
  /// submits it.
  ///
  /// Returns [Allowed] if no constraint fires, [Stop] if [StopIf] matches,
  /// or [Escalated] if [EscalateIf] matches.
  EnforcementResult inspectAnswer(Answer answer, Session session) {
    for (final constraint in _constraints) {
      final result = _inspectAnswerOne(constraint, answer, session);
      if (result is! Allowed) return result;
    }
    return const Allowed();
  }

  EnforcementResult _inspectAnswerOne(
    Constraint constraint,
    Answer answer,
    Session session,
  ) {
    return switch (constraint) {
      // ── EscalateIf ────────────────────────────────────────────────────────
      // Case-insensitive substring match on answer text.
      EscalateIf(:final trigger) => _matchAnswerText(answer, trigger)
          ? Escalated(constraint)
          : const Allowed(),

      // ── StopIf ────────────────────────────────────────────────────────────
      // Case-insensitive substring match on answer text.
      StopIf(:final trigger) => _matchAnswerText(answer, trigger)
          ? Stop(trigger)
          : const Allowed(),

      // All other constraints are step-only checks.
      _ => const Allowed(),
    };
  }

  // ── Completion helpers ────────────────────────────────────────────────────

  /// Returns `false` if any [NeverSkip]-listed field is absent or null in
  /// [session.answers].
  ///
  /// The [OutcomeNavigator] calls this before marking the form complete.
  bool canComplete(Session session) {
    for (final constraint in _constraints) {
      if (constraint case NeverSkip(:final fieldIds)) {
        for (final fieldId in fieldIds) {
          if (session.answers[fieldId] == null) return false;
        }
      }
    }
    return true;
  }

  /// Returns `true` when `session.history.length >= value` for any [MinSteps]
  /// constraint, or `true` when no [MinSteps] constraint is present.
  ///
  /// The Strategy uses this to decide whether to allow an early exit.
  bool isAboveMinimum(Session session) {
    for (final constraint in _constraints) {
      if (constraint case MinSteps(:final value)) {
        return session.history.length >= value;
      }
    }
    // No MinSteps constraint — no floor, always above minimum.
    return true;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Case-insensitive substring check against [answer.answer].
  ///
  /// Checks:
  /// 1. The raw answer value (if it's a String).
  /// 2. If it's a choice/multiChoice, the labels of the selected choices.
  /// 3. If it's a List (multiChoice), all String elements in the list.
  bool _matchAnswerText(Answer answer, String trigger) {
    final needle = trigger.toLowerCase();

    // 1. Check raw answer value (String)
    final rawValue = answer.answer;
    if (rawValue is String) {
      if (rawValue.toLowerCase().contains(needle)) return true;
    }

    // 2. Check choice labels if this was a choice-based step
    final choices = answer.stepSpec.choices;
    if (choices != null && choices.isNotEmpty) {
      if (rawValue is String) {
        // Single choice ID
        final selected = choices.where((c) => c.id == rawValue).firstOrNull;
        if (selected != null &&
            selected.label.toLowerCase().contains(needle)) {
          return true;
        }
      } else if (rawValue is List) {
        // Multiple choice IDs
        final selectedIds = rawValue.map((e) => e.toString()).toSet();
        final selectedChoices = choices.where((c) => selectedIds.contains(c.id));
        for (final c in selectedChoices) {
          if (c.label.toLowerCase().contains(needle)) return true;
        }
      }
    }

    // 3. Check List elements (for cases where raw values are not choice IDs)
    if (rawValue is List) {
      for (final element in rawValue) {
        if (element is String && element.toLowerCase().contains(needle)) {
          return true;
        }
      }
    }

    return false;
  }

  /// The replacement step used by [NeverCollect]: a no-input information step
  /// that tells the user we don't collect this.
  QuizStepSpec _neverCollectSkipStep(String originalId) {
    return QuizStepSpec(
      id: '__never_collect_$originalId',
      title: "We don't collect this. Moving on.",
      inputType: QuizInputType.noneJustInformation,
    );
  }

  /// The replacement step used by [RequireConsent]: a no-input information
  /// step that serves as a consent gate. The FormController writes the topic
  /// to `session.answers['__consents']` once the user acknowledges it.
  QuizStepSpec _consentPromptStep(String topic) {
    return QuizStepSpec(
      id: '__consent_$topic',
      title: 'We need your consent for: $topic',
      description: 'Please review and accept our terms before we continue. '
          'Your answer will be stored under the "$topic" consent record.',
      inputType: QuizInputType.noneJustInformation,
    );
  }
}
