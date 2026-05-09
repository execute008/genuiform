// Contract tests for [A2uiOutcomeSource] implementations.
//
// Any class implementing [A2uiOutcomeSource] must satisfy these assertions.
// To add a new implementation to the contract suite, call
// [runA2uiOutcomeSourceContractTests] from `main()` with an appropriate
// [successFactory].

// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';
import 'package:genuiform_a2ui/genuiform_a2ui.dart';

// ─── Contract harness ─────────────────────────────────────────────────────────

/// Runs the standard [A2uiOutcomeSource] contract assertions against [implName].
///
/// [successFactory] must return a source that, when [emit] is called with any
/// valid arguments, produces the two well-formed A2UI wire envelopes.
void runA2uiOutcomeSourceContractTests({
  required String implName,
  required A2uiOutcomeSource Function() successFactory,
}) {
  group('$implName — A2uiOutcomeSource contract', () {
    test('emit yields exactly two chunks on success', () async {
      final chunks = await successFactory()
          .emit(outcomeId: 'test_outcome', handoff: null, summary: 'summary')
          .toList();

      expect(chunks, hasLength(2));
    });

    test('first chunk decodes to a createSurface envelope', () async {
      final chunks = await successFactory()
          .emit(outcomeId: 'test_outcome', handoff: null, summary: 'summary')
          .toList();

      final first = jsonDecode(chunks[0]) as Map<String, dynamic>;
      expect(first['version'], equals('v0.9'));
      expect(first, contains('createSurface'));
      expect(first, isNot(contains('updateComponents')));
    });

    test('second chunk decodes to an updateComponents envelope', () async {
      final chunks = await successFactory()
          .emit(outcomeId: 'test_outcome', handoff: null, summary: 'summary')
          .toList();

      final second = jsonDecode(chunks[1]) as Map<String, dynamic>;
      expect(second['version'], equals('v0.9'));
      expect(second, contains('updateComponents'));
      expect(second, isNot(contains('createSurface')));
    });

    test('createSurface payload has correct surfaceId and catalogId', () async {
      final chunks = await successFactory()
          .emit(outcomeId: 'test_outcome', handoff: null, summary: 'summary')
          .toList();

      final first = jsonDecode(chunks[0]) as Map<String, dynamic>;
      final cs = first['createSurface'] as Map<String, dynamic>;
      expect(cs['surfaceId'], equals(kA2uiOutcomeSurfaceId));
      expect(cs['catalogId'], equals(kA2uiBasicCatalogId));
    });

    test('updateComponents payload has correct surfaceId and a non-empty components list',
        () async {
      final chunks = await successFactory()
          .emit(outcomeId: 'test_outcome', handoff: null, summary: 'summary')
          .toList();

      final second = jsonDecode(chunks[1]) as Map<String, dynamic>;
      final uc = second['updateComponents'] as Map<String, dynamic>;
      expect(uc['surfaceId'], equals(kA2uiOutcomeSurfaceId));
      final components = uc['components'] as List<dynamic>;
      expect(components, isNotEmpty);
    });

    test('emit returns a Stream (not null)', () {
      final stream = successFactory().emit(
        outcomeId: 'test_outcome',
        handoff: null,
        summary: 'summary',
      );

      expect(stream, isNotNull);
      expect(stream, isA<Stream<String>>());
    });
  });
}

// ─── Fake LLM response for GeminiA2uiOutcomeSource ───────────────────────────

const String _kGeminiSuccessResponse = '''
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
      {"id": "headline", "component": "Text", "text": "Done", "variant": "h2"},
      {"id": "restart_label", "component": "Text", "text": "Restart form"},
      {"id": "restart_btn", "component": "Button", "child": "restart_label",
       "variant": "primary", "action": {"event": {"name": "genuiform/restart"}}}
    ]
  }
}
''';

// ─── Register implementations ─────────────────────────────────────────────────

void main() {
  runA2uiOutcomeSourceContractTests(
    implName: 'GeminiA2uiOutcomeSource',
    successFactory: () => GeminiA2uiOutcomeSource(
      client: FakeLlmClient(scriptedResponses: [_kGeminiSuccessResponse]),
    ),
  );
}
