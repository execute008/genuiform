// All Gemini-specific A2UI outcome generation.
//
// Owns: LlmClient, model selection, responseJsonSchema, the -latest guard,
// buffer-cap, JSON parsing, and envelope splitting.
//
// ─── Why responseJsonSchema (not the legacy OpenAPI subset responseSchema) ───
//
// CHOSEN: a single JSON object with two required top-level keys —
//   { "createSurface": { ... }, "updateComponents": { ... } }
//
// The structured-output validator does not reliably honour `prefixItems`
// (the schema mechanism for an ordered tuple), so a two-element array with
// discriminated union shapes is not viable. `oneOf` over array items would
// also accept arrays in any order or with any mix of message kinds, which
// defeats the purpose. The flat two-property object is cleanly expressible
// and lets the model reason about both halves coherently in a single call.
//
// The legacy `responseSchema` field cannot represent a discriminated union
// of component types. It forces a flat per-item property soup where every
// component object has every possible slot — `text`, `name`, `weight`,
// `action` — regardless of its `component` value. Combined with unbounded
// numerics (the previous schema declared `'weight': {'type': 'number'}`
// with no min/max), this is the documented trigger for Gemini's
// "infinite digit loop on structured output" failure mode: the sampler
// commits a `"weight":` token on a Column root and emits
// `1000000000000000…` until the token budget is exhausted. Reproduced on
// `gemini-2.5-flash`, `gemini-2.5-pro`, `gemini-3-flash-preview` — see
// google-gemini/cookbook#449, langextract#1, the discuss.ai forum threads.
//
// [a2uiOutcomeJsonSchema] closes every known degeneracy slot:
//   1. `anyOf` over per-component branches discriminated on the literal
//      `component` value, so a `Column` only sees Column-shaped slots.
//      (Gemini's `responseJsonSchema` supports `anyOf` per the May 2025
//      announcement; `oneOf` is NOT supported and trips HTTP 400.)
//   2. `additionalProperties: false` at every object level — the model
//      cannot invent fields.
//   3. No unbounded primitives. Every string is enum-pinned or
//      length-capped; no `number`/`integer` properties exist at all.
//   4. The `action` object is deeply bounded down to a single allowed
//      event name ([kA2uiRestartAction]).
//   5. The component enum and the prompt's allowed-component list are in
//      lockstep — no schema-only types like `Image`/`List` to bridge to.

import 'dart:convert';

import 'package:genuiform/genuiform.dart';

import '../a2ui_outcome_prompt.dart';
import '../a2ui_outcome_source.dart';
import '../simulated_handoff.dart';

class GeminiA2uiOutcomeSource implements A2uiOutcomeSource {
  GeminiA2uiOutcomeSource({
    required this.client,
    this.model = 'gemini-2.5-flash',
    this.temperature = 0.7,
    this.maxBufferBytes = 256 * 1024,
  }) {
    // The -latest guard: responseJsonSchema requires 2.5+; -latest aliases
    // route to the gemini-3 preview line which rejects it with HTTP 400.
    if (model.endsWith('-latest')) {
      throw ArgumentError.value(
        model,
        'model',
        'GeminiA2uiOutcomeSource requires a model that accepts '
            'generationConfig.responseJsonSchema. The `-latest` aliases '
            'route to the gemini-3 preview line, which rejects it with '
            'HTTP 400. Pass an explicit version like `gemini-2.5-flash`.',
      );
    }
  }

  final LlmClient client;
  final String model;

  /// Sampling temperature forwarded to [LlmClient.generate]. Defaults to 0.7.
  final double temperature;

  /// Hard cap on the total bytes accumulated from upstream deltas before the
  /// source aborts with a [SchemaError]. Guards against degenerate models
  /// that stream forever (e.g. Gemini 3 Flash preview occasionally enters a
  /// loop emitting the same digit inside a numeric literal). Without this
  /// the loader's outer first-chunk timer eventually fires with a misleading
  /// "first chunk did not arrive" message; the cap turns the failure into an
  /// accurate one originating at the source.
  final int maxBufferBytes;

  @override
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
      responseJsonSchema: a2uiOutcomeJsonSchema(),
      model: model,
      temperature: temperature,
    )) {
      onDelta?.call();
      buffer.write(delta);
      if (buffer.length > maxBufferBytes) {
        throw SchemaError(
          'GeminiA2uiOutcomeSource: upstream LLM exceeded $maxBufferBytes bytes '
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
        'GeminiA2uiOutcomeSource: Vertex response is not valid JSON. Cause: $e',
      );
    }

    final createSurfacePayload = parsed['createSurface'];
    final updateComponentsPayload = parsed['updateComponents'];

    if (createSurfacePayload == null || updateComponentsPayload == null) {
      throw SchemaError(
        'GeminiA2uiOutcomeSource: Vertex response is missing required keys '
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
