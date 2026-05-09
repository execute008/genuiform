import 'a2ui_outcome_source.dart';
import 'simulated_handoff.dart';

/// Wraps an [A2uiOutcomeSource] to emit A2UI v0.9 outcome-screen messages.
///
/// The emitter is a thin delegation shell. All transport-specific logic
/// (model selection, schema, buffer cap) lives in the source.
class A2uiOutcomeEmitter {
  const A2uiOutcomeEmitter({required A2uiOutcomeSource source})
      : _source = source;

  final A2uiOutcomeSource _source;

  /// Delegates to [_source.emit]. See [A2uiOutcomeSource.emit] for the
  /// contract.
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  }) =>
      _source.emit(
        outcomeId: outcomeId,
        handoff: handoff,
        summary: summary,
        onDelta: onDelta,
      );
}
