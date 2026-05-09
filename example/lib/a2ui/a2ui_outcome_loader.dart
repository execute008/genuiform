// Orchestrates a Vertex AI call to produce a live A2UI outcome screen.
//
// Ported from `workbench/lib/src/preview/a2ui_outcome_loader.dart`. See that
// file for the full design rationale (first-chunk timeout, summary format,
// gating ownership). The example loader differs only by import paths.

import 'dart:async';

import 'package:genuiform/genuiform.dart';

import 'a2ui_outcome_emitter.dart';
import 'simulated_handoff.dart';

/// Wraps [A2uiOutcomeEmitter.emit] with:
/// - A summary string built from [FormResult].
/// - A first-chunk timeout (default 30s).
/// - Pass-through error propagation so the renderer can trigger its
///   v1 hand-crafted fallback.
class A2uiOutcomeLoader {
  A2uiOutcomeLoader({required this.emitter})
      : firstChunkTimeout = const Duration(seconds: 30);

  A2uiOutcomeLoader.withTimeout({
    required this.emitter,
    required this.firstChunkTimeout,
  });

  final A2uiOutcomeEmitter emitter;
  final Duration firstChunkTimeout;

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

  static String _buildSummary(String outcomeId, FormResult result) {
    final fields = result.collectedFields;
    if (fields.isEmpty) {
      return 'Outcome: $outcomeId.';
    }
    final pairs = fields.entries.map((e) => '${e.key}=${e.value}').join(', ');
    return 'Outcome: $outcomeId. Fields collected: $pairs.';
  }
}
