# A2UI Option C — v2 spec (overnight)

**Goal.** Take the v1 PoC of option C from a hand-crafted A2UI message rendered
when a hardcoded flag is set, to a real round-trip: when the form completes,
Vertex emits an A2UI v0.9 JSON tree per outcome, the workbench feeds it into
`genui`'s transport, the resulting `Surface` renders inside the form pane,
and a Restart button **inside** the surface dispatches an A2UI action that
restarts the form.

This spec is the input for an overnight Claude Code run. It assumes you've
already read `WORKBENCH_SPEC.md`, `A2UI_AGENDA.md`, the v1 PoC commit
referenced in the agenda's option C entry, and the `genui` 0.9.0 README in
`~/.pub-cache/hosted/pub.dev/genui-0.9.0/README.md`. **Read all four end
to end before writing code.**

---

## 1. State of play

After the v1 PoC, this is what's already on `main`:

- `workbench/lib/src/preview/a2ui_outcome_renderer.dart` — owns a
  `genui.SurfaceController`, hand-feeds it a hardcoded `CreateSurface` +
  `UpdateComponents` pair on init, renders `genui.Surface(...)`. Restart
  button lives **outside** the Surface.
- `FormPreview` swaps to the renderer when
  `--dart-define=USE_A2UI_HANDOFF=true` and `onComplete` fires.
- `genui: ^0.9.0` is a direct dep; 63 transitive packages all compile to
  Flutter Web (JS, not wasm — wasm is out of scope).
- `kHandoffRegistry` in `workbench/lib/src/registry/handoff_registry.dart`
  has 8 entries; `ParseResult.handoffMap` exposes a side-table of
  `outcomeId → SimulatedHandoff`.
- The Vertex transport is `VertexDirectClient` with bearer-token auth and
  schema-constrained JSON output (`responseSchema`).

After v2, the path the user sees is:

```
form completes (onComplete) →
  workbench asks Vertex "emit an A2UI v0.9 message tree for outcome X" →
  Vertex returns JSON →
  workbench feeds it through genui's transport →
  Surface renders →
  user clicks the in-Surface Restart button →
  A2UI action event fires →
  genuiform's form key bumps + the form restarts
```

The default demo path (USE_A2UI_HANDOFF off) stays unchanged.

---

## 2. Constraints that shape this

1. **Stage risk dominates.** This ships for the May 9 demo. If LLM emission
   flakes, fall back gracefully to v1 (hardcoded message). Wrap every
   network and parse step in try/catch and route to a clear visible error
   state — not a frozen pane.
2. **No new backend.** Vertex direct, structured-output JSON, same auth
   path as the existing `VertexDirectClient`. No proxy, no agent server.
3. **Genuiform stays untouched in shape.** No new primitive, no library
   release. Library changes must be additive callbacks at most. If the
   library doesn't expose what's needed, write a workbench-local adapter
   instead of patching the library.
4. **Action roundtrip is workbench-only.** `genui`'s action events stay
   inside the workbench layer; they don't propagate into genuiform's
   `FormController`. The renderer translates an A2UI Restart action into a
   plain Dart callback (the `onRestart` we already pass).
5. **Five outcomes max for v2.** All four bundled scenarios plus a
   fallback for outcomes that have no handoff registered. A scripted A2UI
   tree per outcome is fine; we don't need a fully generative UI per
   outcome until v3.

---

## 3. Architecture

```
workbench/lib/src/
├── preview/
│   ├── a2ui_outcome_renderer.dart   # rewritten: Surface + action dispatcher
│   ├── a2ui_action_handler.dart     # new: wires SurfaceController events
│   │                                #      to onRestart / onShare callbacks
│   └── a2ui_outcome_loader.dart     # new: orchestrates Vertex call + fallback
├── llm/
│   └── a2ui_outcome_emitter.dart    # new: builds the prompt, calls Vertex,
│                                    #      returns A2UI message stream
└── prompts/
    └── a2ui_outcome_prompt.dart     # new: prompt template + responseSchema
```

The dependency graph:

```
FormPreview.onComplete
  → A2uiOutcomeLoader.load(outcomeId, formResult)
      → A2uiOutcomeEmitter.emit(outcomeId, summary, registryHint)
          → VertexDirectClient.generate(...)        // the same client
          → returns Stream<String> of JSON chunks
      → genui.SurfaceController.handleMessage(...)
        (parsed via genui.A2uiParserTransformer)
  → A2uiOutcomeRenderer renders
      ↑
  A2uiActionHandler listens to controller events;
    when an action with `kind: 'workbench/restart'` fires,
    it calls onRestart()
```

---

## 4. Build order (overnight, follow phase by phase)

### Phase 1 — A2UI prompt + schema (60-90 min)

- [ ] Read `~/.pub-cache/hosted/pub.dev/genui-0.9.0/lib/src/catalog/basic_catalog.dart` and `basic_catalog_widgets/{button,column,text,icon,card}.dart` to learn the exact `properties` schema for each component you'll use.
- [ ] Read `~/.pub-cache/hosted/pub.dev/genui-0.9.0/submodules/a2ui/specification/v0_9/json/standard_catalog.json` for the canonical component property names.
- [ ] Create `workbench/lib/src/prompts/a2ui_outcome_prompt.dart` with:
  - `String buildA2uiOutcomePrompt({required String outcomeId, required SimulatedHandoff? handoff, required String summary})` — returns a system prompt string. The prompt must instruct the LLM to:
    - Emit JSON conforming to A2UI v0.9 message format.
    - Use exactly two messages: `{"version": "v0.9", "createSurface": {...}}` and `{"version": "v0.9", "updateComponents": {...}}`.
    - Include a `Button` with id `restart_btn` whose `action` is `{"action": "workbench/restart"}`.
    - Use the `BasicCatalogItems` catalogId (`https://a2ui.org/specification/v0_9/basic_catalog.json`).
    - Use `Column` as the root with id `root`.
  - `Map<String, dynamic> a2uiOutcomeResponseSchema()` — returns a JSON schema constraining Vertex's response to a discriminated union of `createSurface` / `updateComponents`. The schema must be permissive enough to accept any combination of basic-catalog components but require the two top-level message kinds in sequence.
- [ ] Tests in `test/a2ui_outcome_prompt_test.dart`:
  - prompt contains the outcome id, the handoff label (if present), and the catalogId.
  - prompt explicitly forbids interpolation, conditionals, and any deviation from the v0.9 message shape.
  - schema validates against a hand-crafted positive sample (a Column + Text + Button tree); fails against a sample with an unknown component name.

**Decision to surface back to the orchestrator if the schema is hard:** if Gemini's structured-output schema validator can't express the discriminated union in one schema, fall back to making *two separate* Vertex calls — one for `createSurface`, one for `updateComponents` — each with a focused schema. This costs an extra round-trip (~500ms) but is more robust. Document the chosen approach in the file header.

### Phase 2 — Vertex emit path (60-90 min)

- [ ] Create `workbench/lib/src/llm/a2ui_outcome_emitter.dart`:

  ```dart
  class A2uiOutcomeEmitter {
    A2uiOutcomeEmitter({required this.client, this.model = 'gemini-2.5-flash'});

    final LlmClient client;
    final String model;

    /// Returns a stream of raw text chunks suitable for piping into
    /// `genui.A2uiTransportAdapter.addChunk`. The stream yields exactly
    /// what Vertex returns — JSON wrapped in a code fence is fine; the
    /// parser handles it.
    Stream<String> emit({
      required String outcomeId,
      required SimulatedHandoff? handoff,
      required String summary,
    }) async* { ... }
  }
  ```

- [ ] Reuse the existing `VertexDirectClient` — do NOT introduce a new HTTP path. Pass `responseSchema: a2uiOutcomeResponseSchema()` and the system prompt from §4.1.
- [ ] If Vertex returns an error (auth, rate limit, schema mismatch), surface it as a thrown exception. The caller decides the fallback.
- [ ] Tests in `test/a2ui_outcome_emitter_test.dart` using `FakeLlmClient`:
  - emitter passes the prompt + schema to the client correctly.
  - emitter yields the chunks the client streams.
  - emitter propagates `LlmClientError` subtypes (auth, rate-limit, schema) without swallowing them.

### Phase 3 — Action plumbing (45-60 min)

- [ ] Find how `genui` exposes action events. Likely via the `Conversation` facade's `onSubmit` or the `SurfaceController` exposing a `Stream<ChatMessage>` of user submissions. Read `~/.pub-cache/hosted/pub.dev/genui-0.9.0/lib/src/facade.dart` and `lib/src/engine.dart` to confirm. **Document the actual class + method name in the new file's header.**
- [ ] Create `workbench/lib/src/preview/a2ui_action_handler.dart` with:

  ```dart
  class A2uiActionHandler {
    A2uiActionHandler({
      required this.controller,
      required this.onRestart,
    });
    final genui.SurfaceController controller;
    final VoidCallback onRestart;

    StreamSubscription<dynamic>? _sub;

    void start();   // subscribes to controller's submit/event stream;
                    // on a `workbench/restart` action, calls onRestart()
    void dispose(); // cancels subscription
  }
  ```

- [ ] If `genui` doesn't expose action events directly on `SurfaceController` but only through `Conversation`, wire a minimal `Conversation` instead and ignore its LLM transport callback. Keep the explanation in the file header so future-you doesn't wonder why a Conversation exists for a single button.
- [ ] Tests in `test/a2ui_action_handler_test.dart` (widget test): create a `SurfaceController` with `BasicCatalogItems`, dispatch a `CreateSurface` + `UpdateComponents` containing a Button, simulate a tap, assert `onRestart` fires.

### Phase 4 — Renderer rewrite (30-45 min)

- [ ] Rewrite `workbench/lib/src/preview/a2ui_outcome_renderer.dart` (replacing the v1 hand-crafted message path) to:
  - Take a new optional parameter `Stream<String>? a2uiMessageStream`. When provided, pipe its chunks into a `genui.A2uiTransportAdapter` instead of dispatching hand-crafted messages.
  - Keep the v1 hand-crafted path as a *fallback* — if `a2uiMessageStream` is null OR the stream errors before completing, fall back to the static Column + Text + Text tree from v1. Show a small "fallback (LLM emit failed)" badge above the surface in dev mode (`kDebugMode`).
  - Wire an `A2uiActionHandler` from §4.3 to the controller; map the `workbench/restart` action to the existing `onRestart` callback. The Restart button now lives **inside** the Surface; the v1 outside-Restart button is removed.
- [ ] Visual: replace the "rendered via flutter/genui (A2UI v0.9)" footer with a slightly fuller badge: `Icon + 'rendered live by Vertex via flutter/genui (A2UI v0.9)'` to make the round-trip visible.

### Phase 5 — Loader orchestration + FormPreview wiring (45-60 min)

- [ ] Create `workbench/lib/src/preview/a2ui_outcome_loader.dart`:

  ```dart
  class A2uiOutcomeLoader {
    A2uiOutcomeLoader({required this.emitter});
    final A2uiOutcomeEmitter emitter;

    /// Returns a Stream of A2UI text chunks. Wraps the emitter call in
    /// try/catch; on failure, emits a single error event so the renderer
    /// can fall back. Caller is responsible for the timeout.
    Stream<String> load({
      required String outcomeId,
      required SimulatedHandoff? handoff,
      required FormResult result,
    }) async* { ... }
  }
  ```

  Apply a 5-second timeout. If the emitter's first chunk doesn't arrive in
  time, abort and emit a `TimeoutException`. The renderer treats that as
  the fallback trigger.

- [ ] Update `FormPreview`:
  - Add an `A2uiOutcomeEmitter? emitter` field, plumbed in from `AppShell` (which constructs the emitter once per session, sharing the existing `LlmClient`).
  - On `onComplete`, when `_kUseA2uiHandoff && emitter != null`, call `loader.load(...)` and pass the resulting stream to `A2uiOutcomeRenderer`. Otherwise fall through to the existing snackbar path.
  - When `widget.client is _MockLlmClient`, skip the emit path and use the v1 hand-crafted fallback directly. The mock LLM doesn't speak A2UI; trying to call it for emission would error.

- [ ] Update `AppShell`:
  - Construct `A2uiOutcomeEmitter(client: widget.client, model: widget.model)` once in initState and pass to `FormPreview`.

### Phase 6 — Verify, fallback, polish (30-45 min)

- [ ] `flutter analyze` — zero issues.
- [ ] `flutter test` — all tests pass.
- [ ] `flutter build web --release --dart-define=VERTEX_API_KEY=fake --dart-define=VERTEX_PROJECT_ID=fake` — succeeds (no flag — default path unchanged).
- [ ] `flutter build web --release --dart-define=VERTEX_API_KEY=fake --dart-define=VERTEX_PROJECT_ID=fake --dart-define=USE_A2UI_HANDOFF=true` — succeeds.
- [ ] `flutter build web --release --dart-define=USE_MOCK=true --dart-define=USE_A2UI_HANDOFF=true` — succeeds; runtime path uses the v1 fallback (mock can't emit A2UI).
- [ ] Manual smoke (orchestrator runs in Chrome with real Vertex creds):
  1. Run `lead_qualification` to completion. Form pane swaps to the genui-rendered outcome screen with the LLM-emitted content. Click the in-surface Restart → form restarts cleanly.
  2. Disconnect Wi-Fi, repeat. The 5-second timeout fires; the v1 fallback Column appears with the small "fallback" badge. Restart still works.
  3. Run with `USE_MOCK=true`. The form completes against the mock LLM; the v1 fallback surface appears (because the mock doesn't speak A2UI). Restart works.

### Phase 7 — Spec compliance + judging story polish (30 min)

- [ ] Update `A2UI_AGENDA.md`'s option C entry: mark v2 landed; move v3 (action roundtrip beyond Restart, generative UI per outcome) to a new "Backlog" section.
- [ ] Update root `README.md`'s "Relation to A2UI" section: add a short paragraph noting that the workbench now closes the round trip (LLM → A2UI → Surface → action → restart).
- [ ] Update the workbench About modal's A2UI paragraph similarly.
- [ ] Add a one-line `_kUseA2uiHandoff` mention to the workbench README's "Run it" section so anyone repro-ing the demo sees the dart-define.

---

## 5. Failure modes, in order of severity

These will bite during the live demo if not addressed:

1. **Vertex returns malformed A2UI JSON** despite the schema. The genui parser should reject; the loader catches the error and falls back. Verify by feeding a deliberately broken JSON string through the test harness.
2. **Vertex 5-second timeout under stage Wi-Fi.** The 5s loader timeout falls back. Verify by setting the timeout to 100ms and confirming the fallback fires under normal load.
3. **Action event from the in-surface Button doesn't fire.** The Restart UX is broken; the user is stuck on the outcome screen. Mitigation: keep the v1 outside-Restart button as a **secondary** button below the Surface footer when `kDebugMode`; remove for release builds.
4. **The genui `Surface` swallows the entire form pane and forgets the Theme.** `Theme.of(context)` works inside `genui` but the basic-catalog `Text` widget might not pick up the dark Material 3 styling. Verify in Chrome; if it's wrong, wrap the Surface in `Theme(data: workbenchTheme, child: ...)`.
5. **`genui` package update on pub.dev mid-overnight.** Pin `genui: 0.9.0` exactly (no caret) in `workbench/pubspec.yaml` for the duration of the hackathon.
6. **The wasm build's dart:html warning escalates to a JS build failure** if `isolate_contactor` ships a regression. Run `flutter pub outdated` once at start; if `isolate_contactor` jumped a major version, pin it explicitly.

---

## 6. What's NOT in scope for v2

- Multiple A2UI surfaces stacked / a chat-style interface.
- LLM emitting A2UI for *intermediate* steps of the form (only terminal outcomes).
- A2UI-driven `EscalateIf` cards. Keep the existing `_EscalationCard`.
- Agent-to-agent (A2A) protocol; stick with `A2uiTransportAdapter`'s text-stream input.
- Bidirectional data binding for any input components — the outcome screen is read-only plus one Restart button.

---

## 7. The prompt to give Claude Code overnight

Paste this exact text into the overnight Claude Code session:

> I have a Flutter library at the repo root called `genuiform` (see README.md) — a generative-UI form library powered by Vertex AI. There's a companion Flutter Web app at `workbench/` that's the hackathon demo surface. A v1 PoC of A2UI integration (option C) is already on `main`.
>
> Your job is to land the v2 work described in `A2UI_C_V2_SPEC.md`: have Vertex emit A2UI v0.9 JSON for each terminal outcome, render it via Google's `flutter/genui` SDK inside the form pane, and wire an in-surface Restart button through A2UI's action events back to the existing `onRestart` callback. Default demo path stays unchanged.
>
> Read the spec at `A2UI_C_V2_SPEC.md` end to end before writing code. Also read `WORKBENCH_SPEC.md`, `A2UI_AGENDA.md`, and `~/.pub-cache/hosted/pub.dev/genui-0.9.0/README.md`. Follow the build order in §4 phase by phase — do not skip phases, do not jump ahead. Confirm each phase's success criteria before moving to the next.
>
> Critical constraints:
> - The library at `../` from the workbench is a path dependency — don't release it; additive callbacks only if needed.
> - Vertex API key + project come from `--dart-define` exactly as today; never hardcode.
> - Pure Flutter Web, no backend. JS build, not wasm.
> - The `genui` package is pinned at exactly 0.9.0 — don't bump it.
> - Failure must always fall back to the v1 hand-crafted A2UI tree, not crash. The 5-second timeout in §4.5 is the loader's contract.
>
> When you finish a phase, run the workbench in Chrome where possible and verify the success criteria. Report what's working before starting the next phase. If you hit a design decision the spec doesn't cover, ask before guessing.

---

*Spec v0.1 — May 7 2026, Vienna. v1 PoC commit landed earlier today; this document scopes v2 for an overnight run before the May 9 hackathon.*
