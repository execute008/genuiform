// Copyright 2026 Oskar Freye — genuiform workbench
//
// Phase 5 of the A2UI v2 spec (§4.5): loader orchestration.
//
// ─── Purpose ────────────────────────────────────────────────────────────────
//
// [A2uiOutcomeLoader] sits between [FormPreview] and [A2uiOutcomeEmitter].
// It wraps the emitter call with:
//   1. A human-readable summary built from [FormResult] (see "Summary format"
//      below).
//   2. A 5-second timeout on the *first* chunk — if no data arrives within
//      that window the subscription is cancelled and a [TimeoutException] is
//      emitted as a stream error. Subsequent chunks are NOT timeout-bounded
//      once streaming has started.
//   3. Pass-through propagation of any error from the emitter — the loader
//      does not swallow errors. It emits them as stream errors so the renderer
//      can trigger its v1 fallback.
//
// ─── Summary format ─────────────────────────────────────────────────────────
//
// The summary string passed to [A2uiOutcomeEmitter.emit] is constructed from
// [FormResult] as follows:
//
//   "Outcome: <outcomeId>. Fields collected: <fieldId>=<value>, ... ."
//
// Example for a lead_qualification form:
//   "Outcome: book_call. Fields collected: step_name=Alice,
//    step_company=ACME Corp, step_pain=Integration costs too high,
//    step_timeline=immediate."
//
// This format is intentionally concise so it fits comfortably within Vertex's
// context window alongside the system prompt. The LLM uses it to personalise
// the outcome screen text (e.g. greeting the user by name or referencing their
// stated pain point).
//
// Phase 6 / future maintainers: if you want richer context, extend this
// formatter — [A2uiOutcomeEmitter] and [A2uiOutcomeLoader] are the only two
// places that need to change.
//
// ─── Timeout implementation ──────────────────────────────────────────────────
//
// We use an explicit [StreamController] + manual [StreamSubscription] + a
// [Timer] rather than [Stream.timeout] or [async*]. This is because:
//
//   - `async*` doesn't compose cleanly with cancellation on timeout — the
//     generator keeps running after a `yield*`-level timeout.
//   - [Stream.timeout] applies a timeout to every inter-chunk gap, not just
//     the first chunk, which would violate the spec's "first-chunk only" rule.
//   - An explicit [StreamController] gives us precise control: start the timer
//     on subscription, cancel it the moment the first chunk arrives, and
//     propagate errors or cancellation cleanly on timeout.
//
// ─── Gating ownership ───────────────────────────────────────────────────────
//
// [A2uiOutcomeLoader] itself is agnostic to mock vs real clients — it just
// wraps whatever emitter it's given. The mock-client gating decision (skip
// the emit path when the client is [WorkbenchMockLlmClient]) lives in
// [FormPreview], which is the component that has visibility into both the
// client type and the build-time [_kUseA2uiHandoff] flag. See form_preview.dart.
// ────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:genuiform/genuiform.dart';

import '../llm/a2ui_outcome_emitter.dart';
import '../registry/handoff_registry.dart';

/// Orchestrates a Vertex AI call to produce a live A2UI outcome screen.
///
/// Wraps [A2uiOutcomeEmitter.emit] with:
/// - A human-readable summary derived from [FormResult].
/// - A configurable timeout on the first chunk (defaults to 5 seconds per
///   spec §4.5).
/// - Pass-through error propagation (no swallowing).
///
/// The resulting [Stream<String>] is intended to be passed directly to
/// [A2uiOutcomeRenderer.a2uiMessageStream].
class A2uiOutcomeLoader {
  /// Creates an [A2uiOutcomeLoader] with the spec-mandated 5-second
  /// first-chunk timeout.
  A2uiOutcomeLoader({required this.emitter})
      : firstChunkTimeout = const Duration(seconds: 5);

  /// Creates an [A2uiOutcomeLoader] with a custom [firstChunkTimeout].
  ///
  /// Use this constructor in tests to avoid real wall-clock delays.
  A2uiOutcomeLoader.withTimeout({
    required this.emitter,
    required this.firstChunkTimeout,
  });

  /// The underlying emitter that calls Vertex AI.
  final A2uiOutcomeEmitter emitter;

  /// How long to wait for the first chunk before aborting with a
  /// [TimeoutException]. Defaults to 5 seconds (spec §4.5).
  final Duration firstChunkTimeout;

  /// Returns a [Stream<String>] of A2UI wire-format JSON chunks.
  ///
  /// - Builds a summary string from [result] and forwards it to the emitter.
  /// - Applies a [firstChunkTimeout] on the initial chunk.
  /// - Propagates any error (including [TimeoutException]) as a stream error.
  Stream<String> load({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required FormResult result,
  }) {
    final summary = _buildSummary(outcomeId, result);
    final upstream = emitter.emit(
      outcomeId: outcomeId,
      handoff: handoff,
      summary: summary,
    );

    // Use an explicit StreamController so we can control the first-chunk timer
    // and cancellation independently of the upstream subscription lifecycle.
    final controller = StreamController<String>();
    StreamSubscription<String>? subscription;
    Timer? firstChunkTimer;
    bool firstChunkReceived = false;

    void closeWithError(Object error, [StackTrace? stack]) {
      firstChunkTimer?.cancel();
      firstChunkTimer = null;
      if (!controller.isClosed) {
        controller.addError(error, stack ?? StackTrace.current);
        controller.close();
      }
    }

    controller.onListen = () {
      // Start the first-chunk timer immediately when the consumer subscribes.
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

      subscription = upstream.listen(
        (chunk) {
          // Cancel the first-chunk timer on arrival of the first chunk.
          if (!firstChunkReceived) {
            firstChunkReceived = true;
            firstChunkTimer?.cancel();
            firstChunkTimer = null;
          }
          if (!controller.isClosed) {
            controller.add(chunk);
          }
        },
        onError: closeWithError,
        onDone: () {
          firstChunkTimer?.cancel();
          firstChunkTimer = null;
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
      subscription?.cancel();
      subscription = null;
    };

    return controller.stream;
  }

  // ─── Summary builder ──────────────────────────────────────────────────────

  /// Builds the natural-language summary fed to the LLM.
  ///
  /// Format: "Outcome: {outcomeId}. Fields collected: {k}={v}, ... ."
  ///
  /// When [result.collectedFields] is empty, the "Fields collected:" clause is
  /// omitted so the LLM gets clean context even for forms with no explicit
  /// field collection.
  static String _buildSummary(String outcomeId, FormResult result) {
    final fields = result.collectedFields;
    if (fields.isEmpty) {
      return 'Outcome: $outcomeId.';
    }
    final pairs =
        fields.entries.map((e) => '${e.key}=${e.value}').join(', ');
    return 'Outcome: $outcomeId. Fields collected: $pairs.';
  }
}
