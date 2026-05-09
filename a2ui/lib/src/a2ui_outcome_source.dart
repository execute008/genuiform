import 'simulated_handoff.dart';

/// Transport seam for A2UI outcome generation.
///
/// Implement this interface to plug in a different backend (Firebase Vertex,
/// A2A agent, stub) without touching [A2uiOutcomeEmitter] or its callers.
abstract class A2uiOutcomeSource {
  /// Generates A2UI v0.9 outcome-screen messages for [outcomeId].
  ///
  /// Yields exactly two JSON strings on success:
  ///   1. `{"version":"v0.9","createSurface":{...}}`
  ///   2. `{"version":"v0.9","updateComponents":{...}}`
  ///
  /// [onDelta] is called once per upstream delta so the loader's inactivity
  /// watchdog can distinguish "model is silent" from "model is streaming but
  /// not yet producing an envelope".
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  });
}
