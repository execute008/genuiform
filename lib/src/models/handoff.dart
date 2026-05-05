/// Called when a [Layer] or [Outcome] is reached, passing the collected
/// [FormResult] to the consumer for routing/side-effects.
///
/// The parameter is typed as `dynamic` to avoid a circular import between
/// the outcomes tree and `FormResult`. At runtime the value is always a
/// `FormResult` instance — cast it before use:
///
/// ```dart
/// Handoff myHandoff = (result) {
///   final formResult = result as FormResult;
///   // ...
/// };
/// ```
///
/// **Runtime-only — not serialised.** On session resume, the consumer must
/// re-attach the appropriate [Handoff] to each node in the outcome tree.
typedef Handoff = void Function(dynamic result);

/// Called when an [EscalateIf] constraint fires, receiving the [FormResult]
/// at the moment of escalation.
///
/// The parameter is typed as `dynamic` for the same reason as [Handoff] —
/// at runtime the value is always `FormResult`. Cast before use.
///
/// **Runtime-only — not serialised.** Register escalation handlers alongside
/// the [EscalateIf] constraints when building the `GenuiForm`.
typedef EscalationHandler = void Function(dynamic result);
