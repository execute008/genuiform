// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';
import 'package:genuiform_a2ui/genuiform_a2ui.dart';

// ─── Test doubles ─────────────────────────────────────────────────────────────

class _RecordingSource implements A2uiOutcomeSource {
  final List<_SourceCall> calls = [];
  final List<String> _responses;

  _RecordingSource({List<String> responses = const []})
      : _responses = responses;

  @override
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  }) {
    calls.add(_SourceCall(outcomeId: outcomeId, handoff: handoff, summary: summary));
    return Stream.fromIterable(_responses);
  }
}

class _ErrorSource implements A2uiOutcomeSource {
  _ErrorSource(this._error);
  final Object _error;

  @override
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  }) =>
      Stream.error(_error);
}

class _SourceCall {
  final String outcomeId;
  final SimulatedHandoff? handoff;
  final String summary;

  const _SourceCall({required this.outcomeId, required this.handoff, required this.summary});
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('A2uiOutcomeEmitter (delegation layer)', () {
    test('forwards outcomeId, handoff, and summary to the source', () async {
      const handoff = SimulatedHandoff(label: 'Book a call', icon: 'calendar');
      final source = _RecordingSource(responses: ['chunk1', 'chunk2']);
      final emitter = A2uiOutcomeEmitter(source: source);

      await emitter
          .emit(outcomeId: 'book_call', handoff: handoff, summary: 'summary text')
          .toList();

      expect(source.calls, hasLength(1));
      final call = source.calls.first;
      expect(call.outcomeId, equals('book_call'));
      expect(call.handoff, equals(handoff));
      expect(call.summary, equals('summary text'));
    });

    test('yields all chunks from the source in order', () async {
      final source = _RecordingSource(responses: ['a', 'b', 'c']);
      final emitter = A2uiOutcomeEmitter(source: source);

      final chunks = await emitter
          .emit(outcomeId: 'x', handoff: null, summary: '')
          .toList();

      expect(chunks, equals(['a', 'b', 'c']));
    });

    test('propagates errors from the source unchanged', () async {
      const error = SchemaError('boom');
      final source = _ErrorSource(error);
      final emitter = A2uiOutcomeEmitter(source: source);

      Object? caught;
      try {
        await emitter.emit(outcomeId: 'x', handoff: null, summary: '').toList();
      } catch (e) {
        caught = e;
      }

      expect(identical(caught, error), isTrue);
    });

    test('empty response from source yields empty stream', () async {
      final source = _RecordingSource();
      final emitter = A2uiOutcomeEmitter(source: source);

      final chunks = await emitter
          .emit(outcomeId: 'x', handoff: null, summary: '')
          .toList();

      expect(chunks, isEmpty);
    });
  });
}
