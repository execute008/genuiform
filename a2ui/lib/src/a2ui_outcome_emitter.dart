// Calls Vertex AI to produce a live A2UI v0.9 outcome screen and yields
// the resulting wire-format JSON strings for piping into
// `genui.A2uiTransportAdapter.addChunk`.
//
// ─── Output format ──────────────────────────────────────────────────────────
//
// Yields exactly TWO JSON strings on success, in this order:
//
//   1. {"version":"v0.9","createSurface":{...}}
//   2. {"version":"v0.9","updateComponents":{...}}
//
// Each string is a complete, standalone A2UI envelope that
// `A2uiParserTransformer` recognises and dispatches as an `A2uiMessage`.
// Vertex returns a single combined object (per the prompt schema); the
// emitter splits it into the two envelopes the parser expects.
//
// ─── Error handling ─────────────────────────────────────────────────────────
//
// Any `LlmClientError` from `client.generate()` propagates to the stream's
// error channel unchanged. The caller ([A2uiOutcomeLoader]) is responsible
// for catch/fallback logic.

import 'dart:convert';

import 'package:genuiform/genuiform.dart';

import 'a2ui_outcome_prompt.dart';
import 'simulated_handoff.dart';

/// Wraps an [LlmClient] to emit A2UI v0.9 outcome-screen messages.
class A2uiOutcomeEmitter {
  A2uiOutcomeEmitter({
    required this.client,
    this.model = 'gemini-2.5-flash',
    this.maxBufferBytes = 256 * 1024,
  });

  final LlmClient client;
  final String model;

  /// Hard cap on the total bytes accumulated from upstream deltas before the
  /// emitter aborts with a [SchemaError]. Guards against degenerate models
  /// that stream forever (e.g. Gemini 3 Flash preview occasionally enters a
  /// loop emitting the same digit inside a numeric literal). Without this
  /// the loader's outer first-chunk timer eventually fires with a misleading
  /// "first chunk did not arrive" message; the cap turns the failure into an
  /// accurate one originating at the source.
  final int maxBufferBytes;

  /// Calls Vertex once and yields the two A2UI wire envelopes on success.
  ///
  /// [outcomeId] — the outcome identifier from the DSL.
  /// [handoff]   — registered handoff for this outcome (if any). When
  ///               present its label is surfaced to the model as the
  ///               primary headline candidate.
  /// [summary]   — natural-language summary built from the form session;
  ///               passed in the prompt so the LLM can personalise copy.
  /// [onDelta]   — invoked once per upstream delta. Used by the loader's
  ///               inactivity watchdog to distinguish "model is silent" from
  ///               "model is streaming but not yet producing an envelope".
  Stream<String> emit({
    required String outcomeId,
    required SimulatedHandoff? handoff,
    required String summary,
    void Function()? onDelta,
  }) async* {
    final systemPrompt = buildA2uiOutcomePrompt(
      outcomeId: outcomeId,
      handoff: handoff,
      summary: summary,
    );

    // The bundled `LlmClient` implementations buffer the entire HTTP
    // response and yield a single delta at the end, but the API is a
    // stream so we accumulate all deltas before parsing.
    final buffer = StringBuffer();
    await for (final delta in client.generate(
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
      onDelta?.call();
      buffer.write(delta);
      if (buffer.length > maxBufferBytes) {
        throw SchemaError(
          'A2uiOutcomeEmitter: upstream LLM exceeded $maxBufferBytes bytes '
          'without finishing — likely a degenerate response. Aborting.',
        );
      }
    }

    final raw = buffer.toString();
    final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw SchemaError(
        'A2uiOutcomeEmitter: Vertex response is not valid JSON. Cause: $e',
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

    yield jsonEncode({
      'version': 'v0.9',
      'createSurface': createSurfacePayload,
    });

    yield jsonEncode({
      'version': 'v0.9',
      'updateComponents': updateComponentsPayload,
    });
  }
}
