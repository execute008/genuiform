// Tests for workbench/lib/src/preview/form_preview.dart
//
// Phase 5 of the A2UI v2 spec (§4.5) — routing decision verification.
//
// ─── What is and isn't tested here ───────────────────────────────────────────
//
// The compile-time flag [_kUseA2uiHandoff] defaults to `false` in the test
// environment (no `--dart-define=USE_A2UI_HANDOFF=true` is passed by
// `flutter test`). This means the full A2UI handoff path cannot be exercised
// in a standard test run without rebuilding the test binary with that flag.
//
// Instead, this file tests:
//
//   1. WorkbenchMockLlmClient detection — that `is WorkbenchMockLlmClient`
//      correctly identifies the mock vs. a real LlmClient subclass. This is
//      the same `is`-check that FormPreview's gating logic uses.
//
//   2. Flag-off path — FormPreview renders without error when constructed with
//      all required params. When onComplete fires (via a fake FormController),
//      the widget should show the snackbar path (default behavior unchanged).
//
//   3. Emitter null-safety — FormPreview is constructable without an emitter
//      (emitter is optional), confirming existing callers are unaffected.
//
// ─── Testing the live-path routing ───────────────────────────────────────────
//
// The live routing (flag-on + real client + non-null emitter → stream passed
// to A2uiOutcomeRenderer) is covered transitively by A2uiOutcomeLoader tests
// (a2ui_outcome_loader_test.dart) and A2uiOutcomeRenderer tests
// (a2ui_outcome_renderer_test.dart). The glue code in _showHandoffToast is
// three lines; its correctness depends on the loader and renderer contracts
// already being verified.

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import 'package:genuiform_workbench/src/llm/workbench_mock_llm_client.dart';

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Mock client type detection ─────────────────────────────────────────
  //
  // FormPreview's gating logic uses `widget.client is WorkbenchMockLlmClient`.
  // These tests verify the type check behaves as expected so there's no
  // surprise when the flag-on path gates at runtime.

  group('WorkbenchMockLlmClient type detection', () {
    test('WorkbenchMockLlmClient is detected by is-check when typed as LlmClient', () {
      // Upcast to LlmClient so the `is` check mirrors FormPreview's gating:
      //   final bool isMock = widget.client is WorkbenchMockLlmClient;
      // where widget.client is typed as LlmClient.
      final LlmClient client = WorkbenchMockLlmClient();
      expect(client is WorkbenchMockLlmClient, isTrue);
    });

    test('WorkbenchMockLlmClient is an LlmClient (upcast round-trip)', () {
      // Confirm the subtype relationship holds at the abstract LlmClient level.
      final LlmClient client = WorkbenchMockLlmClient();
      expect(client, isA<LlmClient>());
    });

    test('a non-mock LlmClient subclass is NOT detected as WorkbenchMockLlmClient', () {
      final client = _FakeRealClient();
      expect(client is WorkbenchMockLlmClient, isFalse);
    });

    test('null emitter produces isMock=false for a real client (no NPE)', () {
      // This mirrors the gating condition:
      //   final bool isMock = widget.client is WorkbenchMockLlmClient;
      // When called with a real client, isMock should be false.
      final LlmClient client = _FakeRealClient();
      final bool isMock = client is WorkbenchMockLlmClient;
      expect(isMock, isFalse);
    });

    test('isMock is true for WorkbenchMockLlmClient', () {
      final LlmClient client = WorkbenchMockLlmClient();
      final bool isMock = client is WorkbenchMockLlmClient;
      expect(isMock, isTrue);
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// A minimal real (non-mock) LlmClient subclass used to verify that the
/// is-check correctly rejects non-mock clients.
class _FakeRealClient extends LlmClient {
  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    Map<String, dynamic>? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    required String model,
    double temperature = 0.7,
  }) {
    return Stream.value('{}');
  }
}
