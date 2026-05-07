// Copyright 2026 Oskar Freye — genuiform workbench
//
// Prompt template and responseSchema for asking Vertex AI to emit an A2UI v0.9
// outcome screen (Phase 1 of the v2 A2UI spec, §4.1).
//
// ─── Schema approach decision ───────────────────────────────────────────────
//
// CHOSEN: single-object schema wrapping both messages as named properties.
//
// WHY NOT a two-element array with a discriminated union?
// Vertex AI's structured-output validator accepts a subset of JSON Schema
// Draft 2020-12.  `oneOf` / `anyOf` are supported, but `prefixItems` (used to
// express a tuple — an ordered array where each position has its own schema)
// is NOT reliably supported.  The alternative of `items: oneOf[...]` with
// `minItems/maxItems` would accept arrays in any order or with any mix of the
// two message kinds, which defeats the purpose.
//
// CHOSEN SHAPE: a single JSON object with two required top-level keys:
//   {
//     "createSurface": { ... },   // A2UI createSurface payload (no version wrapper)
//     "updateComponents": { ... } // A2UI updateComponents payload (no version wrapper)
//   }
//
// The caller (Phase 2, A2uiOutcomeEmitter) reconstructs the two A2UI wire
// messages by wrapping each payload:
//   {"version":"v0.9","createSurface": response["createSurface"]}
//   {"version":"v0.9","updateComponents": response["updateComponents"]}
//
// This is cleanly expressible as a flat Vertex responseSchema object with two
// required properties — no `oneOf`, no arrays, no `prefixItems`.
//
// WHY NOT two separate Vertex calls?
// The extra round-trip (~500ms) is not worth paying here: the two payloads are
// tightly coupled (the updateComponents surfaceId must match createSurface's
// surfaceId, component IDs must be consistent, etc.).  A single call lets the
// model reason about both halves coherently.  If the single-call schema later
// proves unreliable in practice, splitting is the documented fallback (spec
// §4.1 last paragraph).
// ────────────────────────────────────────────────────────────────────────────

import '../registry/handoff_registry.dart';

/// The catalogId for BasicCatalogItems — canonical URL defined in
/// `genui`'s `primitives/constants.dart` and confirmed in standard_catalog.json.
const String kA2uiBasicCatalogId =
    'https://a2ui.org/specification/v0_9/basic_catalog.json';

/// The surface ID used for all outcome screens.  Must be consistent between
/// the createSurface and updateComponents messages.
const String kA2uiOutcomeSurfaceId = 'outcome_surface';

/// Builds the system prompt that instructs Vertex to emit A2UI v0.9 JSON for
/// the terminal outcome screen.
///
/// The returned string is passed verbatim as `systemInstruction` to
/// [LlmClient.generate].  It tells the model:
/// - What JSON shape to produce (matching [a2uiOutcomeResponseSchema]).
/// - Which catalog to use and what components are allowed.
/// - That the Button with id `restart_btn` must carry the `workbench/restart`
///   action so the workbench can detect and route it.
/// - Hard prohibitions: no interpolation, no conditionals, no free-form text
///   outside the schema, no deviation from the v0.9 message shape.
///
/// [outcomeId]  — the outcome identifier from the DSL (e.g. `"book_call"`).
/// [handoff]    — the registered handoff for this outcome, if any.  When
///                present its [SimulatedHandoff.label] is surfaced to the model
///                as the primary headline text.
/// [summary]    — the natural-language summary emitted by the generative
///                strategy at the end of the session.
String buildA2uiOutcomePrompt({
  required String outcomeId,
  required SimulatedHandoff? handoff,
  required String summary,
}) {
  final handoffContext = handoff != null
      ? 'The outcome reached is "${handoff.label}" (outcome id: "$outcomeId").'
      : 'A generic completion for outcome id: "$outcomeId".';

  return '''
You are an A2UI v0.9 component tree emitter.

Your job is to produce a JSON object describing the completion screen for a
conversational form that just reached a terminal outcome.

## Context

$handoffContext

Session summary from the form:
"$summary"

## Output format

Return EXACTLY one JSON object with two required top-level keys:
  "createSurface" and "updateComponents".

Do NOT add a "version" wrapper — that is added by the caller.
Do NOT add any extra keys beyond "createSurface" and "updateComponents".
Do NOT output markdown fences, prose, or any text outside the JSON object.

### createSurface shape

```
"createSurface": {
  "surfaceId": "$kA2uiOutcomeSurfaceId",
  "catalogId": "$kA2uiBasicCatalogId",
  "sendDataModel": false
}
```

### updateComponents shape

```
"updateComponents": {
  "surfaceId": "$kA2uiOutcomeSurfaceId",
  "components": [ ... array of component objects ... ]
}
```

## Component rules

- Catalog: $kA2uiBasicCatalogId
- Use ONLY these component types: Column, Text, Button, Icon, Card, Divider, Row.
- Every component object MUST have an "id" (unique string) and a "component" key
  naming the type exactly as listed above.
- The root component MUST have id "root" and MUST be a Column.
- The Column's "children" MUST be an array of string IDs referencing other
  components defined in the same "components" array.
- Do NOT nest component definitions inside each other — all components live in
  the flat "components" array, referenced by ID.

### Button requirements

Include a Button with id "restart_btn" whose action is:
```json
{ "event": { "name": "workbench/restart" } }
```
The Button's "child" must be the id of a Text component (e.g. "restart_label").
The Text component's "text" should be "Restart form".
Set the Button's "variant" to "primary".

### Text requirements

Every Text component MUST include a "text" property (a plain string literal —
never a path object or interpolation expression).

### Recommended structure

A good outcome screen typically contains:
1. A headline Text (variant "h2") summarising the outcome label.
2. One or two body Text components with brief contextual copy drawn from the
   session summary above.  Keep copy concise (≤ 30 words per paragraph).
3. The restart_btn Button described above.

Example minimum-viable component array:
```json
[
  { "id": "root", "component": "Column", "justify": "center", "align": "center",
    "children": ["headline", "body", "restart_btn"] },
  { "id": "headline", "component": "Text", "text": "Outcome headline here",
    "variant": "h2" },
  { "id": "body", "component": "Text", "text": "Brief summary sentence.",
    "variant": "body" },
  { "id": "restart_label", "component": "Text", "text": "Restart form" },
  { "id": "restart_btn", "component": "Button", "child": "restart_label",
    "variant": "primary",
    "action": { "event": { "name": "workbench/restart" } } }
]
```

## Hard prohibitions

- NO string interpolation (no \${...} expressions inside text values).
- NO data model path bindings (no {"path": "..."} objects for text values).
- NO conditionals, loops, or any programmatic logic.
- NO components not listed in the "Component rules" section above.
- NO free-form text outside the JSON object.
- NO deviation from the A2UI v0.9 basic-catalog component property names.
- All text MUST be plain string literals — static, not bound to any data model.

Produce the JSON object now.
''';
}

/// Returns a Vertex AI `responseSchema` that constrains the model to emit the
/// combined createSurface + updateComponents object described in
/// [buildA2uiOutcomePrompt].
///
/// ## Schema shape
///
/// The top-level object has two required keys: `"createSurface"` and
/// `"updateComponents"`.  Each key's value schema mirrors the A2UI v0.9
/// message payload (without the `"version"` wrapper, which the caller adds).
///
/// The `components` array inside `updateComponents` is permissive: each item
/// is an object that must have a `"component"` string (naming the catalog
/// type) and an `"id"` string, plus any additional properties allowed by the
/// basic catalog.  A strict `oneOf` discriminator over every possible component
/// type is intentionally omitted here because Vertex's schema validator does
/// not reliably honour deep `oneOf` branches in array items — it tends to
/// reject valid inputs that match one of the alternatives but not another.
/// Instead, `"component"` is constrained to the allowed enum of catalog names,
/// which is sufficient for the workbench's fallback/parsing needs.
///
/// If Vertex's schema validation proves too loose in practice and the LLM
/// starts emitting unknown component types, tighten by adding more required
/// properties per component type or by splitting into two calls.
Map<String, dynamic> a2uiOutcomeResponseSchema() => {
      'type': 'object',
      'required': ['createSurface', 'updateComponents'],
      'properties': {
        'createSurface': {
          'type': 'object',
          'required': ['surfaceId', 'catalogId'],
          'properties': {
            'surfaceId': {'type': 'string'},
            'catalogId': {
              'type': 'string',
              'enum': [kA2uiBasicCatalogId],
            },
            'sendDataModel': {'type': 'boolean'},
          },
        },
        'updateComponents': {
          'type': 'object',
          'required': ['surfaceId', 'components'],
          'properties': {
            'surfaceId': {'type': 'string'},
            'components': {
              'type': 'array',
              'minItems': 1,
              'items': {
                'type': 'object',
                'required': ['id', 'component'],
                'properties': {
                  'id': {'type': 'string'},
                  'component': {
                    'type': 'string',
                    'enum': [
                      'Column',
                      'Row',
                      'Text',
                      'Button',
                      'Icon',
                      'Card',
                      'Divider',
                      'Image',
                      'List',
                    ],
                  },
                  // Layout properties (Column / Row)
                  'justify': {'type': 'string'},
                  'align': {'type': 'string'},
                  'children': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                  // Text
                  'text': {'type': 'string'},
                  'variant': {'type': 'string'},
                  // Button
                  'child': {'type': 'string'},
                  'action': {'type': 'object'},
                  // Icon
                  'name': {'type': 'string'},
                  // Card
                  // (child already declared above)
                  // weight (shared)
                  'weight': {'type': 'number'},
                },
              },
            },
          },
        },
      },
    };
