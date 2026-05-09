// Calls Vertex AI to produce a live A2UI v0.9 outcome screen and yields the
// resulting wire-format JSON strings for piping into
// `genui.A2uiTransportAdapter.addChunk`.
//
// Ported from `workbench/lib/src/llm/a2ui_outcome_emitter.dart`. See that
// file for the full design rationale (why two strings rather than one,
// error propagation, etc.).

import 'dart:convert';

import 'package:genuiform/genuiform.dart';

import 'a2ui_outcome_prompt.dart';
import 'simulated_handoff.dart';

/// Wraps an [LlmClient] to emit A2UI v0.9 outcome-screen messages.
class A2uiOutcomeEmitter {
  A2uiOutcomeEmitter({
    required this.client,
    this.model = 'gemini-2.5-flash',
  });

  final LlmClient client;
  final String model;

  /// Calls Vertex once and yields exactly two JSON envelopes on success:
  ///   1. `{"version":"v0.9","createSurface":{...}}`
  ///   2. `{"version":"v0.9","updateComponents":{...}}`
  ///
  /// Any [LlmClientError] propagates as a stream error. The caller
  /// ([A2uiOutcomeLoader]) is responsible for fallback logic.
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
      buffer.write(delta);
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
