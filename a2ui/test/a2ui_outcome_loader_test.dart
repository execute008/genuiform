// Tests for workbench/lib/src/preview/a2ui_outcome_loader.dart
//
// Covers Phase 5 of the A2UI v2 spec (§4.5):
//
//   1. Happy path — chunks from the emitter are forwarded unchanged.
//   2. Error propagation — LlmClientError subtypes arrive as stream errors.
//   3. Timeout — emitter that never emits → TimeoutException within the
//      configured window (tests override to 100ms for speed).
//   4. Timeout does NOT fire once first chunk arrives — a delayed second
//      chunk still arrives after the timeout window.
//   5. Summary format — collectedFields are serialised correctly.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import 'package:genuiform_a2ui/genuiform_a2ui.dart';

// ─── Fake emitter helpers ─────────────────────────────────────────────────────

/// A minimal fake [A2uiOutcomeEmitter] that returns a pre-configured stream
/// of string chunks. It does NOT actually call Vertex.
class _FakeEmitter extends A2uiOutcomeEmitter {
  _FakeEmitter(this._stream) : super(client: _NoopLlmClient());

  final Stream<String> _stream;

  @override
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  }) =>
      _stream;
}

/// Fake emitter that simulates the buffer-then-yield pattern: it produces no
/// chunks but invokes [onDelta] each time a controller adds. Used to exercise
/// the loader's inactivity watchdog without involving real LLM clients.
class _DeltaSimEmitter extends A2uiOutcomeEmitter {
  _DeltaSimEmitter() : super(client: _NoopLlmClient());

  final StreamController<void> deltas = StreamController<void>.broadcast();

  @override
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  }) async* {
    final sub = deltas.stream.listen((_) => onDelta?.call());
    try {
      // Wait forever — caller cancels via subscription.cancel().
      await Completer<void>().future;
    } finally {
      await sub.cancel();
    }
  }
}

/// An [LlmClient] that should never be called (constructor requirement for
/// [A2uiOutcomeEmitter] but the fake overrides [emit] entirely).
class _NoopLlmClient extends LlmClient {
  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    double temperature = 0.7,
  }) {
    throw StateError('_NoopLlmClient.generate should never be called');
  }
}

/// A fake emitter that records the [summary] and [handoff] it received.
class _CaptureSummaryEmitter extends A2uiOutcomeEmitter {
  _CaptureSummaryEmitter() : super(client: _NoopLlmClient());

  String? capturedSummary;
  SimulatedHandoff? capturedHandoff;

  @override
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  }) {
    capturedSummary = summary;
    capturedHandoff = handoff;
    return Stream.fromIterable(['chunk_one', 'chunk_two']);
  }
}

// ─── FormResult factory helpers ───────────────────────────────────────────────

/// Builds a minimal [FormResult] with the given [collectedFields].
FormResult _result({Map<String, dynamic>? fields}) {
  return FormResult(
    collectedFields: fields ?? const {},
    reachedOutcome: null,
    history: const [],
    status: SessionStatus.completed,
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  const shortTimeout = Duration(milliseconds: 100);

  // ── 1. Happy path ─────────────────────────────────────────────────────────

  group('A2uiOutcomeLoader — happy path', () {
    test('forwards all chunks from the emitter unchanged', () async {
      const chunks = ['chunk_a', 'chunk_b', 'chunk_c'];
      final emitter = _FakeEmitter(Stream.fromIterable(chunks));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      final result = await loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .toList();

      expect(result, equals(chunks));
    });

    test('works with a single-chunk stream', () async {
      final emitter = _FakeEmitter(Stream.value('only_chunk'));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      final result = await loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .toList();

      expect(result, equals(['only_chunk']));
    });

    test('stream closes cleanly after all chunks arrive', () async {
      final emitter = _FakeEmitter(Stream.fromIterable(['a', 'b']));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      final chunks = <String>[];
      await for (final c in loader.load(
        outcomeId: 'x',
        handoff: null,
        result: _result(),
      )) {
        chunks.add(c);
      }

      expect(chunks, equals(['a', 'b']));
    });
  });

  // ── 2. Error propagation ──────────────────────────────────────────────────

  group('A2uiOutcomeLoader — error propagation', () {
    test('propagates AuthError as stream error', () async {
      const error = AuthError('Bad key');
      final emitter = _FakeEmitter(Stream.error(error));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      await expectLater(
        loader.load(outcomeId: 'x', handoff: null, result: _result()),
        emitsError(isA<AuthError>()),
      );
    });

    test('propagates RateLimitError as stream error', () async {
      const error = RateLimitError('Quota hit');
      final emitter = _FakeEmitter(Stream.error(error));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      await expectLater(
        loader.load(outcomeId: 'x', handoff: null, result: _result()),
        emitsError(isA<RateLimitError>()),
      );
    });

    test('propagates SchemaError as stream error', () async {
      const error = SchemaError('Bad schema');
      final emitter = _FakeEmitter(Stream.error(error));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      await expectLater(
        loader.load(outcomeId: 'x', handoff: null, result: _result()),
        emitsError(isA<SchemaError>()),
      );
    });

    test('propagates NetworkError as stream error', () async {
      const error = NetworkError('Offline');
      final emitter = _FakeEmitter(Stream.error(error));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      await expectLater(
        loader.load(outcomeId: 'x', handoff: null, result: _result()),
        emitsError(isA<NetworkError>()),
      );
    });

    test('emits no data chunks before the error — stream has only error event',
        () async {
      const error = AuthError('gone');
      final emitter = _FakeEmitter(Stream.error(error));
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      // expectLater with emitsDone would fail because the stream errors.
      // Instead verify no data chunks precede the error using a completer.
      final dataChunks = <String>[];
      final errorCompleter = Completer<Object>();

      loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .listen(
            dataChunks.add,
            onError: errorCompleter.complete,
            cancelOnError: true,
          );

      final caught = await errorCompleter.future;

      expect(dataChunks, isEmpty);
      expect(caught, isA<AuthError>());
    });
  });

  // ── 3. Timeout — emitter never emits ─────────────────────────────────────

  group('A2uiOutcomeLoader — timeout on first chunk', () {
    test('emits TimeoutException when no chunk arrives within the timeout',
        () async {
      // A stream controller that is never closed / never adds anything.
      final controller = StreamController<String>();
      addTearDown(controller.close);

      final emitter = _FakeEmitter(controller.stream);
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      await expectLater(
        loader.load(outcomeId: 'x', handoff: null, result: _result()),
        emitsError(isA<TimeoutException>()),
      );
    });

    test('TimeoutException carries the correct duration', () async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      final emitter = _FakeEmitter(controller.stream);
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: shortTimeout,
      );

      final errorCompleter = Completer<Object>();
      loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .listen(
            (_) {},
            onError: errorCompleter.complete,
            cancelOnError: true,
          );

      final caught = await errorCompleter.future;

      expect(caught, isA<TimeoutException>());
      final te = caught as TimeoutException;
      expect(te.duration, equals(shortTimeout));
    });
  });

  // ── 4. Timeout does NOT fire after the first chunk ────────────────────────

  group('A2uiOutcomeLoader — timeout cancelled after first chunk', () {
    test('slow second chunk still arrives when first chunk was on time',
        () async {
      // Emit first chunk immediately, then second chunk after the timeout has
      // passed (relative to subscription time).
      final controller = StreamController<String>();

      final emitter = _FakeEmitter(controller.stream);
      // Use a 50ms timeout; second chunk will arrive at ~120ms.
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: const Duration(milliseconds: 50),
      );

      final chunks = <String>[];
      final done = Completer<void>();

      loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .listen(
            chunks.add,
            onDone: done.complete,
            onError: done.completeError,
          );

      // First chunk arrives immediately — cancels the 50ms timer.
      controller.add('first');

      // Second chunk arrives after the timeout window (120ms > 50ms).
      await Future<void>.delayed(const Duration(milliseconds: 120));
      controller.add('second');
      await controller.close();

      await done.future;

      expect(chunks, equals(['first', 'second']));
    });
  });

  // ── 4b. Inactivity watchdog ───────────────────────────────────────────────
  //
  // Independent of "first chunk arrived?", the loader must distinguish a
  // silent stall (no upstream deltas) from steady-but-unproductive streaming.
  // The emitter signals upstream activity via an `onDelta` callback; the
  // loader resets its inactivity timer on each call.
  group('A2uiOutcomeLoader — inactivity watchdog', () {
    test('fires TimeoutException when emitter delivers no deltas', () async {
      final emitter = _DeltaSimEmitter();
      addTearDown(emitter.deltas.close);
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: const Duration(seconds: 30),
        inactivityTimeout: const Duration(milliseconds: 80),
      );

      final caught = Completer<Object>();
      loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .listen(
            (_) {},
            onError: caught.complete,
            cancelOnError: true,
          );

      final err = await caught.future;
      expect(err, isA<TimeoutException>());
      expect(
        (err as TimeoutException).message,
        contains('no LLM activity'),
        reason:
            'Inactivity timeout must use a message that names the real cause '
            '(no deltas) rather than the misleading "first chunk".',
      );
    });

    test('does not fire while deltas keep arriving', () async {
      final emitter = _DeltaSimEmitter();
      addTearDown(emitter.deltas.close);
      // Inactivity = 80ms, but we'll add() every 30ms, so timer keeps
      // resetting for the duration of the test.
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: emitter,
        firstChunkTimeout: const Duration(seconds: 30),
        inactivityTimeout: const Duration(milliseconds: 80),
      );

      final caught = Completer<Object>();
      final sub = loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .listen(
            (_) {},
            onError: caught.complete,
            cancelOnError: true,
          );
      addTearDown(sub.cancel);

      // Pump 8 deltas at 30ms intervals → 240ms elapsed. With an 80ms
      // inactivity timeout, the watchdog would have fired ≥3× without resets.
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        emitter.deltas.add(null);
      }

      // Verify watchdog has NOT fired despite > inactivityTimeout total time.
      expect(caught.isCompleted, isFalse);
    });

    test('default inactivityTimeout is set on the no-arg constructor', () {
      // Regression guard: the default-args constructor must wire up an
      // inactivity timeout (the caller doesn't have to specify one).
      final loader = A2uiOutcomeLoader(emitter: _FakeEmitter(const Stream.empty()));
      expect(
        loader.inactivityTimeout,
        greaterThan(Duration.zero),
        reason:
            'Default inactivity watchdog must be enabled, not Duration.zero.',
      );
      expect(
        loader.inactivityTimeout,
        lessThanOrEqualTo(const Duration(seconds: 30)),
        reason:
            'Default inactivity timeout should be tighter than the total '
            'first-chunk deadline so silent stalls fail before steady-streaming '
            'degeneracy hits the outer cap.',
      );
    });
  });

  // ── 5. Default first-chunk timeout ────────────────────────────────────────

  group('A2uiOutcomeLoader — default first-chunk timeout', () {
    test('default constructor sets a timeout that accommodates buffered LLM clients',
        () {
      // Regression guard: VertexDirectClient and GeminiApiClient both buffer
      // the entire HTTP response before yielding a single chunk, so the
      // "first chunk" arrival time equals the entire LLM call wall-clock
      // time. For gemini-flash-latest with structured output, this routinely
      // exceeds 5s. The default timeout must be generous enough to cover
      // realistic LLM round-trips, otherwise the renderer falls back to v1.
      final emitter = _FakeEmitter(const Stream.empty());
      final loader = A2uiOutcomeLoader(emitter: emitter);

      expect(
        loader.firstChunkTimeout,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
        reason: 'Default first-chunk timeout was 5s, which triggered '
            'TimeoutException on slow first responses (e.g. Gemini AI Studio '
            'free tier with structured output).',
      );
    });
  });

  // ── 6. Summary format ─────────────────────────────────────────────────────

  group('A2uiOutcomeLoader — summary building', () {
    test('summary with no fields is just the outcome id', () async {
      final cap = _CaptureSummaryEmitter();
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: cap,
        firstChunkTimeout: shortTimeout,
      );

      await loader
          .load(outcomeId: 'book_call', handoff: null, result: _result())
          .toList();

      expect(cap.capturedSummary, equals('Outcome: book_call.'));
    });

    test('summary includes collected field key=value pairs', () async {
      final cap = _CaptureSummaryEmitter();
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: cap,
        firstChunkTimeout: shortTimeout,
      );

      await loader
          .load(
            outcomeId: 'book_call',
            handoff: null,
            result: _result(fields: {
              'step_name': 'Alice',
              'step_company': 'ACME',
            }),
          )
          .toList();

      expect(cap.capturedSummary, contains('Outcome: book_call'));
      expect(cap.capturedSummary, contains('Fields collected:'));
      expect(cap.capturedSummary, contains('step_name=Alice'));
      expect(cap.capturedSummary, contains('step_company=ACME'));
    });

    test('handoff is passed through to the emitter', () async {
      const handoff = SimulatedHandoff(label: 'Book a call', icon: 'calendar');
      final cap = _CaptureSummaryEmitter();
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: cap,
        firstChunkTimeout: shortTimeout,
      );

      await loader
          .load(outcomeId: 'book_call', handoff: handoff, result: _result())
          .toList();

      expect(cap.capturedHandoff, equals(handoff));
    });

    test('null handoff is passed through to the emitter', () async {
      final cap = _CaptureSummaryEmitter();
      final loader = A2uiOutcomeLoader.withTimeout(
        emitter: cap,
        firstChunkTimeout: shortTimeout,
      );

      await loader
          .load(outcomeId: 'x', handoff: null, result: _result())
          .toList();

      expect(cap.capturedHandoff, isNull);
    });
  });
}
