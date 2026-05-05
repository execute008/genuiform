// Pure Dart — no Flutter imports.

import '../models/session.dart';
import '../models/step_event.dart';
import 'form_config.dart';

/// The abstract base for all form strategies.
///
/// A [Strategy] takes the current [Session] and [FormConfig] and emits a
/// [Stream<StepEvent>] describing what should happen next in the conversation.
///
/// Concrete implementations:
/// - [GenerativeStrategy] — every step emitted by the LLM, schema-constrained.
/// - [GuidedStrategy] — picks the next step from a developer-supplied catalog.
///
/// Strategies are **stateless** — all state lives in [Session]. Each call to
/// [nextStep] may be called with a new session after the user answers.
abstract class Strategy {
  /// Determines the next action for the form conversation.
  ///
  /// Emits one or more [StepEvent]s on the returned stream. Errors from the
  /// LLM or runtime are always surfaced as [StreamError] events — the stream
  /// never throws.
  Stream<StepEvent> nextStep(Session session, FormConfig config);
}
