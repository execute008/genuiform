# a2ui integration — agenda

Tracking how genuiform sits next to / on top of Google's
[A2UI protocol](https://a2ui.org) and the [`flutter/genui`](https://github.com/flutter/genui)
SDK, ahead of the May 9 2026 hackathon.

## Positioning

**genuiform vs a2ui in one line.** a2ui hands the LLM a UI canvas; genuiform
hands it a typed `Contract`, hard `Constraint`s, a soft `Posture`, and a
predefined tree of `OutcomeNode`s. Where a2ui asks "what should the UI look
like this turn?", genuiform asks "what should we ask next, given an
invariant of what may ever be collected and where the form may ever land?".

genuiform is the higher-abstraction layer. a2ui is what you'd use underneath
if you wanted to free up the per-step UI rendering further.

## Ecosystem packages on pub.dev (as of May 2026)

| Package | Purpose |
|---|---|
| `genui` 0.9.0 | A2UI v0.9 renderer — `Surface`, `SurfaceController`, `Conversation`, `A2uiTransportAdapter`, catalogs |
| `genui_a2a` 0.9.0 | WebSocket connector for A2A-protocol agents |
| `genai_primitives` 0.9.0 | Shared AI primitives |
| `json_schema_builder` 0.9.0 | Schema helpers used by the catalog system |

All four list Web among supported platforms.

## Options

### A — Positioning only (committed: pending)

Document genuiform as a "constraints layer above a2ui-style generative UI".

- update repo `README.md` with a one-paragraph "Relation to a2ui" section
- mirror it in the workbench About dialog so the §7 demo flow can reference
  Google's a2ui standard out loud
- update the workbench landing description to say "form layer above
  a2ui-style generative UI"

Effort: ~30 min. Risk: zero. Hackathon credit: meaningful (judges who know
a2ui will see the thoughtful framing).

### B — `A2uiTransportClient` LlmClient (committed: backlog)

Add an `A2uiTransportClient` next to `VertexDirectClient` /
`VertexProxyClient` / `FakeLlmClient` that speaks the A2UI message protocol
to a remote agent and maps responses into genuiform's `QuizStepSpec` schema.

- new file `lib/src/llm/a2ui_transport_client.dart`
- depends on `genui` for the protocol types or hand-rolls them from the spec
- requires a reference A2A-protocol server to call against — `flutter/genui`
  has the verdure example we could repurpose

Effort: ~1 day. Risk: low (isolated to one client class). Value: lets
genuiform consume any a2ui-compatible backend; a useful answer to the
"what about Google's standard?" question.

### C — `A2uiStepRenderer` for handoff/escalation UIs (PoC: ✅ landed; v2: backlog)

For terminal `Outcome`s, render the completion screen via `genui`'s
`Surface` widget instead of a handoff toast, driven by a hand-crafted A2UI
component message.

**Original effort estimate**: ~2 days. **Actual PoC effort**: ~30 minutes
once I had the `genui` API surface mapped. Initial estimate was wrong
because I assumed I'd need to either implement A2UI rendering myself or
fight the dep tree. `genui` 0.9.0 resolves cleanly on Flutter Web, exposes
a clean four-class public API (`SurfaceController`, `Component`,
`UpdateComponents`, `Surface`), and the basic catalog covers everything
needed for a completion screen.

PoC implementation (committed):
- new file `workbench/lib/src/preview/a2ui_outcome_renderer.dart` — owns
  a `SurfaceController`, hand-feeds it a `CreateSurface` + `UpdateComponents`
  pair on init (Column root with two Text children), renders the resulting
  `Surface(surfaceContext: controller.contextFor(id))`
- conditional path in `FormPreview.onComplete`: when
  `--dart-define=USE_A2UI_HANDOFF=true`, the form pane swaps for
  `A2uiOutcomeRenderer` instead of showing a SnackBar; a footer badge reads
  "rendered via flutter/genui (A2UI v0.9)" so judges can see the integration
- 1 dependency added: `genui: ^0.9.0` (pulls 63 transitive packages
  including `url_launcher`, `video_player` — all support web)
- Restart button is a regular Flutter button outside the `Surface`, so this
  PoC sidesteps A2UI action-event roundtripping; that's the v2 work

PoC validation results:
1. ✅ `genui` resolves and builds cleanly on Flutter Web with the workbench's
   existing deps (`re_editor`, `archive`, `web`, etc.)
2. ✅ `Surface` renders a hand-crafted A2UI message inside the form pane
   without owning the whole screen
3. ✅ The resulting Flutter widget tree integrates with the existing
   Material 3 dark theme via `Theme.of(context)`

The wasm dry-run reports `dart:html unsupported` from
`isolate_contactor` (a `genui` transitive dep). This affects wasm only;
the JS web build succeeds. Not blocking.

**v2 work to land before the demo if we want full a2ui-emit-by-LLM:**
- Have Vertex emit A2UI v0.9 JSON for each outcome via structured output
  (`responseSchema`), keyed off the handoff registry name; pipe through
  `A2uiTransportAdapter.addChunk`. Estimate: ~2-4 hours, blocked only on
  drafting the per-outcome system prompt.
- Wire A2UI `action` events back to genuiform's restart flow so the
  Restart button can live inside the Surface. Estimate: ~1-2 hours.

If we land both v2 items, the demo gains a genuine "form completes →
LLM-emitted A2UI screen renders → Restart triggers via A2UI action" round
trip. That's a much stronger judging story than the toast.

## Decision log

- 2026-05-07 — initial assessment, recommended option A only for hackathon
  scope.
- 2026-05-07 — user redirected: agenda all three, PoC option C to validate
  the complexity estimate.
- 2026-05-07 — PoC landed in 30 min vs the 2-day estimate. Option C is
  feasible; v2 (LLM emits A2UI, action roundtrip) is a 3-6h follow-on.
  Recommend: do option A now (positioning), land v2 of option C tomorrow.
