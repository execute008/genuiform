// Copyright 2026 Oskar Freye — genuiform workbench
//
// Phase 2 of the A2UI v2 spec (§4.2): Vertex emit path.
//
// ─── Output format ──────────────────────────────────────────────────────────
//
// The emitter yields exactly TWO JSON strings, in this order:
//
//   1. {"version":"v0.9","createSurface":{...}}
//   2. {"version":"v0.9","updateComponents":{...}}
//
// Each string is a complete, standalone JSON object that `genui`'s
// `A2uiTransportAdapter.addChunk` (and the underlying
// `A2uiParserTransformer`) will recognise and dispatch as an `A2uiMessage`.
//
// Verified against:
//   ~/.pub-cache/hosted/pub.dev/genui-0.9.0/lib/src/model/a2ui_message.dart
//   line 23 — `if (version != 'v0.9') throw A2uiValidationException(...)`
//   line 29 — `if (json case {'createSurface': JsonMap data})`
//   line 40 — `if (json case {'updateComponents': JsonMap data})`
//
// The caller (Phase 4, A2uiOutcomeRenderer) is expected to feed each yielded
// chunk to `A2uiTransportAdapter.addChunk(chunk)`.
//
// ─── Why two strings, not one ───────────────────────────────────────────────
//
// Vertex returns a single JSON object (per the Phase 1 schema design) with
// two top-level keys: `createSurface` and `updateComponents`.  The genui
// parser does NOT recognise this combined shape — it expects each wire message
// to be a self-contained A2UI envelope with `"version":"v0.9"`.  The emitter
// therefore splits the single Vertex response into the two envelopes genui
// expects.
//
// ─── Error handling ─────────────────────────────────────────────────────────
//
// Any `LlmClientError` that arrives on the `generate()` error channel is
// re-thrown directly onto the emitter's stream error channel.  The caller
// (Phase 5, A2uiOutcomeLoader) is responsible for catch/fallback logic.
// ────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:genuiform/genuiform.dart';

import '../prompts/a2ui_outcome_prompt.dart';
import '../registry/handoff_registry.dart';

/// Calls Vertex AI to produce a live A2UI v0.9 outcome screen and yields the
/// resulting wire-format JSON strings for piping into
/// `genui.A2uiTransportAdapter.addChunk`.
///
/// ### Usage
///
/// ```dart
/// final emitter = A2uiOutcomeEmitter(client: vertexClient);
/// await for (final chunk in emitter.emit(
///   outcomeId: 'book_call',
///   handoff: handoff,
///   summary: 'Qualified lead.',
/// )) {
///   transportAdapter.addChunk(chunk);
/// }
/// ```
///
/// ### Stream contract
///
/// The stream yields exactly two strings on success:
///   - `{"version":"v0.9","createSurface":{...}}`
///   - `{"version":"v0.9","updateComponents":{...}}`
///
/// On any `LlmClientError` the stream emits the error and closes.
class A2uiOutcomeEmitter {
  /// Creates an [A2uiOutcomeEmitter].
  ///
  /// [client] is the shared [LlmClient] instance (typically
  /// [VertexDirectClient] in production; a [FakeLlmClient] in tests).
  ///
  /// [model] defaults to `'gemini-2.5-flash'` — the same default used
  /// throughout the workbench.
  A2uiOutcomeEmitter({
    required this.client,
    this.model = 'gemini-2.5-flash',
  });

  /// The underlying LLM transport.
  final LlmClient client;

  /// Vertex model ID string.
  final String model;

  /// Builds the prompt, calls Vertex, parses the response, and yields the two
  /// A2UI wire-format JSON strings.
  ///
  /// [outcomeId] — the DSL outcome identifier (e.g. `'book_call'`).
  /// [handoff]   — the registered `SimulatedHandoff` for this outcome, if any.
  /// [summary]   — the natural-language summary from the completed form session.
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
  }) async* {
    final systemPrompt = buildA2uiOutcomePrompt(
      outcomeId: outcomeId,
      handoff: handoff,
      summary: summary,
    );

    // client.generate() emits on its error channel for LlmClientError
    // subtypes; we propagate those by awaiting each event and letting the
    // async* generator's implicit error channel pass them through.
    await for (final rawChunk in client.generate(
      systemPrompt: systemPrompt,
      messages: [
        Message(
          role: MessageRole.user,
          content: 'Generate the outcome screen now.',
        ),
      ],
      responseSchema: a2uiOutcomeResponseSchema(),
      model: model,
    )) {
      // Vertex returns one complete JSON string (buffered by VertexDirectClient).
      // Parse it and reconstruct the two A2UI wire envelopes.
      final Map<String, dynamic> parsed;
      try {
        parsed = (jsonDecode(rawChunk) as Map<String, dynamic>);
      } catch (e) {
        // The raw response is not valid JSON — treat as a schema error.
        throw SchemaError(
          'A2uiOutcomeEmitter: Vertex response is not valid JSON. '
          'Cause: $e',
        );
      }

      final createSurfacePayload = parsed['createSurface'];
      final updateComponentsPayload = parsed['updateComponents'];

      if (createSurfacePayload == null || updateComponentsPayload == null) {
        throw SchemaError(
          'A2uiOutcomeEmitter: Vertex response is missing required keys '
          '"createSurface" or "updateComponents". Got keys: ${parsed.keys}',
        );
      }

      // Yield the createSurface envelope.
      yield jsonEncode({
        'version': 'v0.9',
        'createSurface': createSurfacePayload,
      });

      // Yield the updateComponents envelope.
      yield jsonEncode({
        'version': 'v0.9',
        'updateComponents': updateComponentsPayload,
      });
    }
  }
}
