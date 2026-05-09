// Tests for workbench/lib/src/llm/a2ui_outcome_emitter.dart
//
// Covers Phase 2 of the A2UI v2 spec (§4.2):
//   1. Prompt + schema forwarded correctly to the underlying LlmClient.
//   2. Valid Vertex response is split into two A2UI wire-format JSON strings.
//   3. LlmClientError subtypes (auth, rate-limit, schema) propagate unchanged.
//
// Uses the library-provided [FakeLlmClient] from `package:genuiform/genuiform.dart`
// so that there is no duplication of test infrastructure.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import 'package:genuiform_a2ui/genuiform_a2ui.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Minimal valid Vertex response payload: a single JSON object with both
/// `createSurface` and `updateComponents` top-level keys.
///
/// Matches the Phase 1 schema design (a2uiOutcomeResponseSchema).
const String _kValidVertexResponse = '''
{
  "createSurface": {
    "surfaceId": "outcome_surface",
    "catalogId": "https://a2ui.org/specification/v0_9/basic_catalog.json",
    "sendDataModel": false
  },
  "updateComponents": {
    "surfaceId": "outcome_surface",
    "components": [
      {"id": "root", "component": "Column", "children": ["headline", "restart_btn"]},
      {"id": "headline", "component": "Text", "text": "Book a call", "variant": "h2"},
      {"id": "restart_label", "component": "Text", "text": "Restart form"},
      {"id": "restart_btn", "component": "Button", "child": "restart_label",
       "variant": "primary", "action": {"event": {"name": "genuiform/restart"}}}
    ]
  }
}
''';

/// A [FakeLlmClient] that throws the supplied error on `generate()`.
///
/// We can't configure [FakeLlmClient] to throw errors (it only emits values),
/// so we create a minimal subclass for the error-propagation tests.
class _ErrorLlmClient extends LlmClient {
  _ErrorLlmClient(this._error);

  final LlmClientError _error;

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    double temperature = 0.7,
  }) {
    return Stream.error(_error);
  }
}

/// An [LlmClient] that yields a fixed list of [_deltas] in order, simulating
/// the post-streaming-refactor [VertexDirectClient]/[GeminiApiClient] contract
/// where multiple deltas arrive over the lifetime of a single generate() call.
class _StreamingLlmClient extends LlmClient {
  _StreamingLlmClient(this._deltas);

  final List<String> _deltas;

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    double temperature = 0.7,
  }) {
    return Stream<String>.fromIterable(_deltas);
  }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('A2uiOutcomeEmitter', () {
    // ── Test 1: prompt + schema forwarded correctly ───────────────────────────
    group('forwards prompt and schema to LlmClient.generate', () {
      test('systemPrompt contains the outcome id', () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        await emitter
            .emit(
              outcomeId: 'book_call',
              handoff: null,
              summary: 'Test summary.',
            )
            .toList(); // drain the stream

        expect(fake.invocations, hasLength(1));
        final inv = fake.invocations.first;
        expect(inv.systemPrompt, contains('book_call'));
      });

      test('systemPrompt contains the handoff label when provided', () async {
        const handoff = SimulatedHandoff(label: 'Book a call', icon: 'calendar');
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        await emitter
            .emit(
              outcomeId: 'book_call',
              handoff: handoff,
              summary: 'Qualified lead.',
            )
            .toList();

        final inv = fake.invocations.first;
        expect(inv.systemPrompt, contains('Book a call'));
        expect(inv.systemPrompt, contains('book_call'));
      });

      test('responseSchema matches a2uiOutcomeResponseSchema()', () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        await emitter
            .emit(outcomeId: 'x', handoff: null, summary: '')
            .toList();

        final capturedSchema = fake.invocations.first.responseSchema;
        final expectedSchema = a2uiOutcomeResponseSchema();

        // Compare serialised form so nested map equality is deep.
        expect(
          jsonEncode(capturedSchema),
          equals(jsonEncode(expectedSchema)),
        );
      });

      test('model defaults to gemini-2.5-flash', () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        await emitter
            .emit(outcomeId: 'x', handoff: null, summary: '')
            .toList();

        expect(fake.invocations.first.model, equals('gemini-2.5-flash'));
      });

      test('custom model is forwarded', () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(
          client: fake,
          model: 'gemini-2.0-pro',
        );

        await emitter
            .emit(outcomeId: 'x', handoff: null, summary: '')
            .toList();

        expect(fake.invocations.first.model, equals('gemini-2.0-pro'));
      });
    });

    // ── Test 2: correct wire-format chunks are yielded ────────────────────────
    group('yields A2UI wire-format JSON strings', () {
      test('emits exactly two chunks for a valid response', () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        final chunks = await emitter
            .emit(outcomeId: 'book_call', handoff: null, summary: 'summary')
            .toList();

        expect(chunks, hasLength(2));
      });

      test('first chunk is a createSurface envelope with version v0.9', () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        final chunks = await emitter
            .emit(outcomeId: 'book_call', handoff: null, summary: 'summary')
            .toList();

        final first = jsonDecode(chunks[0]) as Map<String, dynamic>;
        expect(first['version'], equals('v0.9'));
        expect(first, contains('createSurface'));
        expect(first, isNot(contains('updateComponents')));
      });

      test(
          'second chunk is an updateComponents envelope with version v0.9',
          () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        final chunks = await emitter
            .emit(outcomeId: 'book_call', handoff: null, summary: 'summary')
            .toList();

        final second = jsonDecode(chunks[1]) as Map<String, dynamic>;
        expect(second['version'], equals('v0.9'));
        expect(second, contains('updateComponents'));
        expect(second, isNot(contains('createSurface')));
      });

      test('createSurface payload matches the Vertex response payload',
          () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        final chunks = await emitter
            .emit(outcomeId: 'book_call', handoff: null, summary: 'summary')
            .toList();

        final first = jsonDecode(chunks[0]) as Map<String, dynamic>;
        final cs = first['createSurface'] as Map<String, dynamic>;
        expect(cs['surfaceId'], equals('outcome_surface'));
        expect(
          cs['catalogId'],
          equals('https://a2ui.org/specification/v0_9/basic_catalog.json'),
        );
      });

      test('updateComponents payload contains the components from the response',
          () async {
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        final chunks = await emitter
            .emit(outcomeId: 'book_call', handoff: null, summary: 'summary')
            .toList();

        final second = jsonDecode(chunks[1]) as Map<String, dynamic>;
        final uc = second['updateComponents'] as Map<String, dynamic>;
        expect(uc['surfaceId'], equals('outcome_surface'));
        final components = uc['components'] as List<dynamic>;
        expect(components, hasLength(4));
        final ids = components.map((c) => (c as Map)['id']).toList();
        expect(ids, containsAll(['root', 'headline', 'restart_btn']));
      });
    });

    // ── Test 3: LlmClientError subtypes propagate unchanged ──────────────────
    group('propagates LlmClientError subtypes without swallowing', () {
      test('AuthError propagates', () async {
        const error = AuthError('Invalid API key');
        final client = _ErrorLlmClient(error);
        final emitter = A2uiOutcomeEmitter(client: client);

        await expectLater(
          emitter.emit(outcomeId: 'x', handoff: null, summary: ''),
          emitsError(isA<AuthError>()),
        );
      });

      test('RateLimitError propagates', () async {
        const error = RateLimitError('Quota exceeded');
        final client = _ErrorLlmClient(error);
        final emitter = A2uiOutcomeEmitter(client: client);

        await expectLater(
          emitter.emit(outcomeId: 'x', handoff: null, summary: ''),
          emitsError(isA<RateLimitError>()),
        );
      });

      test('SchemaError propagates', () async {
        const error = SchemaError('Response does not match schema');
        final client = _ErrorLlmClient(error);
        final emitter = A2uiOutcomeEmitter(client: client);

        await expectLater(
          emitter.emit(outcomeId: 'x', handoff: null, summary: ''),
          emitsError(isA<SchemaError>()),
        );
      });

      test('NetworkError propagates', () async {
        const error = NetworkError('Connection refused');
        final client = _ErrorLlmClient(error);
        final emitter = A2uiOutcomeEmitter(client: client);

        await expectLater(
          emitter.emit(outcomeId: 'x', handoff: null, summary: ''),
          emitsError(isA<NetworkError>()),
        );
      });

      test('preserved error is identical instance (not wrapped)', () async {
        const original = AuthError('token expired');
        final client = _ErrorLlmClient(original);
        final emitter = A2uiOutcomeEmitter(client: client);

        Object? caught;
        try {
          await emitter.emit(outcomeId: 'x', handoff: null, summary: '').toList();
        } catch (e) {
          caught = e;
        }

        // The same object should propagate — no wrapping.
        expect(identical(caught, original), isTrue);
      });
    });

    // ── Streaming: multiple deltas from upstream ─────────────────────────────
    group('accumulates deltas from a streaming LlmClient', () {
      test('yields exactly two envelopes when the response arrives as N deltas',
          () async {
        // Slice the valid response into 4 roughly-equal chunks to simulate
        // SSE deltas arriving over time. The emitter must accumulate them
        // before parsing.
        final full = _kValidVertexResponse;
        final chunkSize = (full.length / 4).ceil();
        final deltas = <String>[
          for (int i = 0; i < full.length; i += chunkSize)
            full.substring(i, (i + chunkSize).clamp(0, full.length)),
        ];
        expect(deltas.length, greaterThan(1),
            reason: 'Test must exercise multi-delta path');
        expect(deltas.join(), equals(full),
            reason: 'Deltas must concatenate back to the full payload');

        final client = _StreamingLlmClient(deltas);
        final emitter = A2uiOutcomeEmitter(client: client);

        final chunks = await emitter
            .emit(outcomeId: 'book_call', handoff: null, summary: 's')
            .toList();

        expect(chunks, hasLength(2));
        final first = jsonDecode(chunks[0]) as Map<String, dynamic>;
        final second = jsonDecode(chunks[1]) as Map<String, dynamic>;
        expect(first, contains('createSurface'));
        expect(second, contains('updateComponents'));
      });

      test('does not throw on partial-JSON intermediate deltas', () async {
        // Each individual delta is invalid JSON on its own; only the
        // concatenation parses. The current per-chunk-jsonDecode emitter
        // throws SchemaError on the very first delta.
        final deltas = ['{"createSur', 'face":{"surfaceId":"s","catalogId":"c","sendDataModel":false},'
            '"updateComponents":{"surfaceId":"s","components":[]}}'];
        final client = _StreamingLlmClient(deltas);
        final emitter = A2uiOutcomeEmitter(client: client);

        final chunks = await emitter
            .emit(outcomeId: 'x', handoff: null, summary: '')
            .toList();

        expect(chunks, hasLength(2));
      });
    });

    // ── Runaway upstream guard ────────────────────────────────────────────────
    //
    // Regression: gemini-3-flash-preview occasionally goes degenerate and
    // streams the same digit forever inside a numeric literal (e.g.
    // `"weight":1.01121111…`). The buffer-then-parse emitter has no notion of
    // "this stream is producing garbage" so it accumulates indefinitely and
    // the loader's first-chunk timer fires with a misleading "first chunk did
    // not arrive within Ns" message. The cap turns that into an accurate
    // SchemaError originating at the emitter, and bounds memory.
    group('runaway upstream guard', () {
      test('throws SchemaError once buffered text exceeds maxBufferBytes',
          () async {
        // 32 deltas × 1024 chars = 32 KB > 16 KB cap.
        final delta = '1' * 1024;
        final client = _StreamingLlmClient(List<String>.filled(32, delta));
        final emitter = A2uiOutcomeEmitter(
          client: client,
          maxBufferBytes: 16 * 1024,
        );

        Object? caught;
        try {
          await emitter
              .emit(outcomeId: 'x', handoff: null, summary: '')
              .toList();
        } catch (e) {
          caught = e;
        }

        expect(caught, isA<SchemaError>());
        expect(
          (caught as SchemaError).toString(),
          contains('exceeded'),
          reason: 'Error must name the real cause (runaway upstream), not a '
              'misleading downstream symptom.',
        );
      });

      test('does not throw when buffered text stays within maxBufferBytes',
          () async {
        // The valid response is well under 16 KB.
        final fake = FakeLlmClient(
          scriptedResponses: [_kValidVertexResponse],
        );
        final emitter = A2uiOutcomeEmitter(
          client: fake,
          maxBufferBytes: 16 * 1024,
        );

        final chunks = await emitter
            .emit(outcomeId: 'x', handoff: null, summary: '')
            .toList();

        expect(chunks, hasLength(2));
      });

      test('default maxBufferBytes is generous enough for normal envelopes',
          () async {
        // Normal A2UI envelopes are 5–20 KB. The default must clear that with
        // headroom; 64 KB minimum is the contract.
        final emitter = A2uiOutcomeEmitter(
          client: _ErrorLlmClient(const SchemaError('unused')),
        );
        expect(
          emitter.maxBufferBytes,
          greaterThanOrEqualTo(64 * 1024),
        );
      });
    });

    // ── Edge case: invalid JSON from client ───────────────────────────────────
    group('handles unexpected client responses', () {
      test('throws SchemaError when client emits non-JSON', () async {
        final fake = FakeLlmClient(
          scriptedResponses: ['this is not json'],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        await expectLater(
          emitter.emit(outcomeId: 'x', handoff: null, summary: ''),
          emitsError(isA<SchemaError>()),
        );
      });

      test(
          'throws SchemaError when response JSON is missing createSurface key',
          () async {
        final fake = FakeLlmClient(
          scriptedResponses: ['{"updateComponents": {"surfaceId": "s", "components": []}}'],
        );
        final emitter = A2uiOutcomeEmitter(client: fake);

        await expectLater(
          emitter.emit(outcomeId: 'x', handoff: null, summary: ''),
          emitsError(isA<SchemaError>()),
        );
      });
    });
  });
}
