// Orchestrates a Vertex call to produce a live A2UI outcome screen.
//
// ─── Purpose ────────────────────────────────────────────────────────────────
//
// [A2uiOutcomeLoader] sits between the consumer (FormPreview / ScenarioPage)
// and [A2uiOutcomeEmitter]. It wraps the emitter call with:
//   1. A summary string built from [FormResult].
//   2. A timeout on the *first* chunk — if no data arrives within that
//      window the subscription is cancelled and a [TimeoutException]
//      propagates as a stream error. Subsequent chunks are NOT
//      timeout-bounded once streaming has started. Bundled `LlmClient`
//      implementations buffer the full HTTP response and yield a single
//      chunk, so this is effectively a total-call deadline.
//   3. Pass-through error propagation. Errors are not swallowed — they
//      propagate so the renderer can trigger its v1 fallback.
//
// ─── Timeout implementation ──────────────────────────────────────────────────
//
// We use an explicit `StreamController` + manual subscription + `Timer`
// rather than `Stream.timeout` or `async*` because:
//   - `async*` doesn't compose cleanly with cancellation on timeout.
//   - `Stream.timeout` applies to every inter-chunk gap, not just the
//     first chunk, which would violate the spec's "first-chunk only" rule.
//   - The explicit controller gives precise control: start the timer on
//     subscription, cancel it the moment the first chunk arrives, and
//     propagate errors or cancellation cleanly on timeout.

import 'dart:async';

import 'package:genuiform/genuiform.dart';

import 'a2ui_outcome_emitter.dart';
import 'simulated_handoff.dart';

/// Wraps [A2uiOutcomeEmitter.emit] with a summary, first-chunk timeout, and
/// pass-through error propagation.
class A2uiOutcomeLoader {
  /// Creates an [A2uiOutcomeLoader] with the default 30-second
  /// first-chunk timeout — sized to cover realistic gemini-2.5-flash
  /// latency for structured-output calls — and a 15-second inactivity
  /// watchdog that fires when the upstream LLM stops emitting deltas
  /// before producing a parseable envelope.
  A2uiOutcomeLoader({required this.emitter})
      : firstChunkTimeout = const Duration(seconds: 30),
        inactivityTimeout = const Duration(seconds: 15);

  /// Custom-timeout constructor used in tests to avoid real wall-clock
  /// delays.
  A2uiOutcomeLoader.withTimeout({
    required this.emitter,
    required this.firstChunkTimeout,
    this.inactivityTimeout = const Duration(seconds: 15),
  });

  final A2uiOutcomeEmitter emitter;
  final Duration firstChunkTimeout;

  /// How long the upstream LLM may go without producing any delta before the
  /// loader aborts with a [TimeoutException]. Independent of
  /// [firstChunkTimeout]: the first-chunk timer measures "no parsed envelope
  /// yet"; inactivity measures "no upstream activity at all". The latter is
  /// what catches dropped connections and silent stalls.
  final Duration inactivityTimeout;

  /// Returns a stream of A2UI wire-format JSON chunks suitable for piping
  /// into [A2uiOutcomeRenderer.a2uiMessageStream].
  Stream<String> load({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required FormResult result,
  }) {
    final summary = _buildSummary(outcomeId, result);

    final controller = StreamController<String>();
    StreamSubscription<String>? subscription;
    Timer? firstChunkTimer;
    Timer? inactivityTimer;
    bool firstChunkReceived = false;

    void closeWithError(Object error, [StackTrace? stack]) {
      firstChunkTimer?.cancel();
      firstChunkTimer = null;
      inactivityTimer?.cancel();
      inactivityTimer = null;
      if (!controller.isClosed) {
        controller.addError(error, stack ?? StackTrace.current);
        controller.close();
      }
    }

    void resetInactivityTimer() {
      inactivityTimer?.cancel();
      inactivityTimer = Timer(inactivityTimeout, () {
        subscription?.cancel();
        subscription = null;
        closeWithError(
          TimeoutException(
            'A2uiOutcomeLoader: no LLM activity for '
            '${inactivityTimeout.inSeconds}s — aborting emit.',
            inactivityTimeout,
          ),
        );
      });
    }

    final upstream = emitter.emit(
      outcomeId: outcomeId,
      handoff: handoff,
      summary: summary,
      onDelta: resetInactivityTimer,
    );

    controller.onListen = () {
      firstChunkTimer = Timer(firstChunkTimeout, () {
        subscription?.cancel();
        subscription = null;
        closeWithError(
          TimeoutException(
            'A2uiOutcomeLoader: first chunk did not arrive within '
            '${firstChunkTimeout.inSeconds}s — aborting emit.',
            firstChunkTimeout,
          ),
        );
      });
      resetInactivityTimer();

      subscription = upstream.listen(
        (chunk) {
          if (!firstChunkReceived) {
            firstChunkReceived = true;
            firstChunkTimer?.cancel();
            firstChunkTimer = null;
          }
          // A yielded chunk also counts as activity — keep the watchdog
          // armed while subsequent chunks are still arriving.
          resetInactivityTimer();
          if (!controller.isClosed) {
            controller.add(chunk);
          }
        },
        onError: closeWithError,
        onDone: () {
          firstChunkTimer?.cancel();
          firstChunkTimer = null;
          inactivityTimer?.cancel();
          inactivityTimer = null;
          if (!controller.isClosed) {
            controller.close();
          }
        },
        cancelOnError: true,
      );
    };

    controller.onCancel = () {
      firstChunkTimer?.cancel();
      firstChunkTimer = null;
      inactivityTimer?.cancel();
      inactivityTimer = null;
      subscription?.cancel();
      subscription = null;
    };

    return controller.stream;
  }

  /// Builds the natural-language summary fed to the LLM.
  ///
  /// Format: `"Outcome: {outcomeId}. Fields collected: {k}={v}, ... ."`
  ///
  /// When `result.collectedFields` is empty, the "Fields collected:" clause
  /// is omitted so the LLM gets clean context even for forms with no
  /// explicit field collection.
  static String _buildSummary(String outcomeId, FormResult result) {
    final fields = result.collectedFields;
    if (fields.isEmpty) {
      return 'Outcome: $outcomeId.';
    }
    final pairs = fields.entries.map((e) => '${e.key}=${e.value}').join(', ');
    return 'Outcome: $outcomeId. Fields collected: $pairs.';
  }
}
