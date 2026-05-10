# genuiform — Generative UI Forms for Flutter

**Adaptive forms that read the room.** A Flutter library for building forms that decide *what to ask, in what order, with what wording, and where the conversation should land* — within hard constraints you specify and a soft posture you configure. Powered by Gemini.

> Built for the [Generative UI Global Hackathon](https://generativeuihackathon.com) (Vienna, May 9 2026).
> Live workbench: **<https://workbench.genuiform.draht.dev>** · Landing: **<https://genuiform.draht.dev>**

---

## TL;DR

```dart
final form = GenuiForm(
  contract: leadContract,
  constraints: [NeverCollect('payment_info'), MaxSteps(8)],
  posture: Posture.salesDiscovery(),
  outcomes: leadOutcomes,
  client: GeminiApiClient(apiKey: kGeminiKey),
  model: 'gemini-2.5-flash',
  onComplete: (result) => print(result.outcome),
);
```

Four typed primitives — `Contract`, `Constraints`, `Posture`, `Outcomes` — define the runtime invariants. Inside that envelope, an LLM picks each next step. **Generative inside, predictable outside.**

---

## 1. Why this exists

Static multi-step forms have three failure modes:

1. **Redundancy.** A returning user answers the same questions again because the form has no memory.
2. **Wasted depth.** A confused user gets the same 15 questions as a confident one. A senior CTO with a clear brief gets the same flow as a first-time founder.
3. **Dead-end framing.** The wording was written once, for a generic user. It never adapts to the answers it has already collected.

`genuiform` treats the form as a *conversation with a goal*. Each step is decided in context: what the user has already said, what's still unknown, how engaged they seem, and what the form is trying to learn.

---

## 2. Live workbench (the killer artifact)

The fastest way to grok what this library does is to open the workbench and edit the DSL on the left while the form rebuilds on the right.

**<https://workbench.genuiform.draht.dev>**

```
┌──────────────────────────┬───────────────────────────┐
│  // edit the DSL         │  What's your company?     │
│  final form = GenuiForm( │  [ Acme Industries     ]  │
│    contract: ...         │              [ Next ]     │
│    constraints: [...],   │                           │
│    posture: ...,         │  ─────────────────────    │
│    outcomes: ...,        │  step 3 · strong · path   │
│  );                      │                           │
│  ✓ parsed cleanly        │                           │
└──────────────────────────┴───────────────────────────┘
```

Features:
- Live parse-and-rebuild — every keystroke retypes the four primitives
- Scenario presets (lead qualification, GymGeist onboarding, newsletter, medical intake)
- Model picker, temperature slider, progress drawer, DSL autocomplete + reference
- A2UI outcome rendering — terminal screens emitted by Gemini and rendered through `flutter/genui`
- URL-hash state so any DSL is shareable
- Bring-your-own Gemini key (paste once, kept in process only)

Source: [`workbench/`](workbench) · spec: [`WORKBENCH_SPEC.md`](WORKBENCH_SPEC.md)

---

## 3. Quick start

### 3.1 Run the example app locally

```bash
git clone https://github.com/execute008/genuiform
cd genuiform/example
flutter run -d macos --dart-define=GEMINI_API_KEY=$YOUR_GEMINI_KEY
```

Web is intentionally excluded for the example — `GeminiApiClient` bundles the key client-side and a browser would expose it. Use `-d macos` / `-d linux` / `-d ios` / a connected device.

Get a free key from [Google AI Studio](https://aistudio.google.com/apikey). If you skip `--dart-define`, the app shows an "API key" panel on startup; the value lives only in the running process.

### 3.2 Run the workbench locally

```bash
cd genuiform/workbench
flutter run -d chrome
```

The workbench targets web. Same API-key story — paste once on first load.

### 3.3 Use the library in your app

Until pub.dev publication, depend via path or git:

```yaml
dependencies:
  genuiform:
    git:
      url: https://github.com/execute008/genuiform
```

Then construct a form with the four primitives — see [`example/lib/scenarios/`](example/lib/scenarios) for two complete configs.

---

## 4. Relation to A2UI

Google's [A2UI protocol](https://a2ui.org) (and the [`flutter/genui`](https://pub.dev/packages/genui) SDK that implements it) lets an AI agent emit a UI structure each turn — components, data bindings, layout — and have the client render it. **A2UI is a UI canvas for agents.**

`genuiform` is a layer above that. Where A2UI asks *"what should the UI look like this turn?"*, genuiform asks *"what should we ask next, given an invariant of what may ever be collected and where the form may ever land?"*.

| | A2UI / `flutter/genui` | `genuiform` |
|---|---|---|
| Who designs the UI | the agent (per turn) | the developer (once, via the four primitives) |
| Per-turn payload | UI components + data bindings | a typed `QuizStepSpec` |
| Runtime guarantees | none — the agent draws what it wants | `Contract` / `Constraints` / `Posture` / `Outcomes` are hard |
| Use when | you want generative UIs everywhere | you want generative UIs *bounded* by a typed schema, hard never-collect rules, and a closed set of allowed completions |

The two compose. The library proper (`genuiform`) stays inside its typed primitives during form collection. When the form completes, a sibling package — [`genuiform_a2ui`](a2ui) — pipes the `OutcomeReached` event into Gemini, asks for an A2UI v0.9 message pair, and renders the resulting Surface via `flutter/genui`. The in-Surface "Restart" button dispatches an A2UI action back into the workbench. See [`A2UI_C_V2_SPEC.md`](A2UI_C_V2_SPEC.md) for the spec and [`A2UI_AGENDA.md`](A2UI_AGENDA.md) for status.

---

## 5. The four primitives

Each primitive answers a different question. They compose; they don't overlap.

| Primitive | Answers | Enforced by |
|---|---|---|
| `Contract` | What data must be collected? | Runtime (completion check) |
| `Constraints` | What must never happen? | Runtime (every turn) |
| `Posture` | How should the form behave? | LLM (prompt) |
| `Outcomes` | Where can the form end up? | LLM picks, runtime routes |

Each is independently testable, debuggable, and tunable. A safety incident traces to a constraint. An ergonomics complaint traces to posture. A routing bug traces to outcomes. A missing-data bug traces to contract. No conflation.

**Hard vs soft.** Two primitives are runtime-enforced — `Contract` and `Constraints`. Two are LLM-interpreted — `Posture` and the routing decisions inside `Outcomes`. The things that *must* happen don't depend on the LLM cooperating; the things that should *feel right* do.

### 5.1 Contract — what data must be collected

```dart
final leadContract = Contract(fields: {
  'name':       FieldSpec(type: String, required: true),
  'company':    FieldSpec(type: String, required: true),
  'pain_point': FieldSpec(
    type: String, required: true,
    description: 'The concrete problem they want solved',
  ),
  'timeline':   FieldSpec(
    type: String, required: true,
    enumValues: ['immediate', '1-3 months', '3-6 months', '6+'],
  ),
  'budget_eur': FieldSpec(type: int, required: false),
  'role':       FieldSpec(
    type: String, required: false,
    enumValues: ['decision_maker', 'influencer', 'researcher'],
  ),
});
```

The form is incomplete until every `required: true` field has a valid value. The runtime checks the contract — the LLM doesn't decide completion based on vibes. The LLM's only job is to keep asking until the contract is fillable, and to signal when no further question can extract a missing field.

Field `description` is fed into the LLM prompt verbatim. Prompt engineering moves out of the system prompt and into the schema where it belongs.

### 5.2 Constraints — what must never happen

Invariants enforced by the runtime, checked every turn, override any LLM output that violates them.

```dart
final gymConstraints = [
  NeverSkip(['height_cm', 'weight_kg']),     // BMR calc — non-negotiable
  MaxSteps(15),
  EscalateIf(
    'user mentions eating disorder, purging, or extreme calorie restriction',
    handler: ReferToProfessionalSupport(),
  ),
  EscalateIf('user describes injury during exercise', handler: ReferToMedical()),
  StopIf('user is under 16'),
];
```

Available variants: `NeverCollect`, `NeverSkip`, `MaxSteps`, `MinSteps`, `WhitelistChoices`, `EscalateIf`, `StopIf`, `RequireConsent`. You could put "never collect SSN" in a system prompt — the LLM would mostly comply. For things that matter (medical, legal, safety), `mostly` is unacceptable.

### 5.3 Posture — how the form behaves

```dart
class Posture {
  final int persistence;     // 1-5: how hard to push when answers are vague
  final int exploration;     // 1-5: how willing to follow tangents
  final int pacing;          // 1-5: how aggressively to deepen the conversation
  final int skipTolerance;   // 1-5: how easily to accept "I don't want to answer"
  final String voice;        // free-text tone description
}
```

Presets ship for `salesDiscovery()`, `supportiveOnboarding()`, `clinicalIntake()`. The most important knob is `pacing` — combined with the LLM's per-turn engagement read (strong/weak/negative), it controls whether the form pushes deeper through the outcome tree or gracefully exits at the current `Layer`. This is what static forms cannot do.

### 5.4 Outcomes — where the form can end up

A tree of three node types — `Layer`, `Branch`, `Outcome` — that compose freely.

```dart
// Branching: mutually exclusive endings, LLM picks
Branch('lead_split', options: [
  BranchOption('book_call',     when: 'qualified + budget fits + decision-maker'),
  BranchOption('send_proposal', when: 'qualified + needs more info'),
  BranchOption('decline',       when: 'budget mismatch or red flag'),
])

// Ladder: progressive depth, user advances if engaged
Layer('account_only', next:
  Layer('with_workout_plan', next:
    Layer('with_full_setup', next: null)))

// Composed: branches inside ladders, ladders inside branches
Layer('account_only', next:
  Layer('with_workout_plan', next:
    Branch('nutrition_path', [...])))
```

**Contract composition rule.** The running contract at any point is the merge of every `contractDelta` on the path root → current node, *including the chosen `BranchOption`*. Layers contribute when entered. Branch options contribute when chosen. Outcomes contribute on completion. One symmetric rule across three node types.

**Layer exit-offer.** When a `Layer` completes and engagement is weak (per `posture.pacing`), the LLM emits an `offer_exit` step rather than continuing into `next`. The `Session.pendingExitLayerId` field carries this state across turns so the prompt can disambiguate "the user accepted the exit" from "the user wants to keep going." See `lib/src/strategies/prompt_builder.dart`.

---

## 6. Sessions, strategies, and the LLM client

```dart
class Session {
  final OutcomeNode currentNode;
  final List<Answer> history;            // {stepId, stepSpec, answer, timestamp}
  final Map<String, dynamic> answers;    // flat lookup for completion checks
  final Contract runningContract;        // composed from path through tree
  final SessionStatus status;            // active | completed | abandoned | escalated
  final EngagementSignal lastSignal;     // strong | weak | negative
  final Outcome? reachedOutcome;
  final String? pendingExitLayerId;      // see §5.4
}
```

Sessions are immutable — each turn produces a new one. JSON-serializable for resume.

**Strategies.** A `Strategy` decides what step to emit next. Two ship today:

- `GenerativeStrategy` — every step emitted by the LLM, constrained by a JSON response schema. The default; what the workbench and example use.
- `GuidedStrategy` — picks the next step from a developer-supplied catalog of `QuizStepSpec` definitions. Lower latency, more predictable, less magical.

**LLM client.** A single transport ships in v0.1: `GeminiApiClient`, which calls Google AI Studio's REST endpoint with a static `AIza...` key. Suitable for the workbench, the example, and server-side usage. **Never bundle the key into a shipped mobile app** — wrap `FirebaseVertexAI.instance` (or your own proxy) behind an `LlmClient` adapter instead. A `vertex_proxy_client.dart` constructor stub exists for this; the proxy implementation lives in your codebase.

The Gemini system prompt is **cached across turns** in the same session via Gemini's `cachedContent` API — first turn pays the full prompt cost, subsequent turns reference the cache. See [`lib/src/llm/gemini_api_client.dart`](lib/src/llm/gemini_api_client.dart).

---

## 7. Repository layout

```
genuiform/                            # this monorepo
├── lib/                              # the genuiform package itself
│   ├── genuiform.dart                # public exports
│   └── src/
│       ├── models/                   # Contract, Constraints, Posture, Outcomes,
│       │                             # Session, FieldSpec, QuizStepSpec, …
│       ├── strategies/               # Strategy interface + Generative/Guided
│       ├── llm/                      # LlmClient, GeminiApiClient, FakeLlmClient,
│       │                             # vertex_proxy_client.dart (stub),
│       │                             # response schemas
│       ├── runtime/                  # ConstraintEnforcer, OutcomeNavigator,
│       │                             # EngagementReader
│       ├── widgets/                  # GenuiForm, FormController, StepRenderer,
│       │                             # input renderers, dev tools
│       └── icons/                    # IconRegistry (~160 Material icons)
├── a2ui/                             # genuiform_a2ui — A2UI v0.9 plumbing
│                                     # (emitter, loader, renderer, action handler)
├── workbench/                        # genuiform_workbench Flutter web app
│                                     # — the live editor + preview demo
├── example/                          # runnable Flutter app, two scenarios
├── www/
│   ├── demo/                         # Material 3 demo deployed at
│   │                                 # workbench.genuiform.draht.dev
│   ├── landing/                      # React landing at genuiform.draht.dev
│   └── sst.config.ts                 # SST infra config
├── examples/firebase-proxy/          # reference Firebase Function proxy
├── integration_test/                 # gated end-to-end Gemini smoke tests
├── test/                             # unit + widget tests (491+ at last count)
├── A2UI_AGENDA.md                    # A2UI integration phase tracker
├── A2UI_C_V2_SPEC.md                 # A2UI option-C v2 implementation spec
├── WORKBENCH_SPEC.md                 # workbench architecture spec
└── CHANGELOG.md
```

The library has been split into two pub-publishable packages — `genuiform` (typed primitives + form runtime) and `genuiform_a2ui` (A2UI outcome rendering). The split keeps the core dependency-free of `package:genui` so apps that only want the form loop don't pull the A2UI surface SDK.

---

## 8. Status

**v0.1 (current).** The four primitives, both strategies, `GenuiForm` widget, `FormController`, `GeminiApiClient` with system-prompt caching, layer exit-offer state, the workbench, two example scenarios, and the A2UI outcome integration are all shipping. The library is usable end-to-end against Gemini today; pub.dev publication is gated on the GymGeist integration validating the API.

**Tracked deferrals.**
- `back()` on `FormController` restores from history but does not regenerate via the LLM.
- Streaming partial JSON is buffered until the full response is valid (no incremental render).
- `VertexProxyClient` is a constructor stub — bring your own proxy implementation.
- Session persistence helper (resume support) — Sessions are JSON-serializable today; a saved-resume helper is not.
- The icon registry ships in full (~2.2k chars in the system prompt); curating to a per-form subset is a v0.2 optimization.

See [`CHANGELOG.md`](CHANGELOG.md) for the per-version log.

---

## 9. Pricing & latency notes

Indicative figures as of May 2026 — Gemini 3.x models are still preview and pricing may shift before GA.

| Model | Per-step latency | Cost per step (~1.5k in / 400 out) | Best for |
|---|---|---|---|
| `gemini-2.5-flash` | 1.0–1.8s | ~€0.0004 | Stable production default. GA through Oct 16 2026. |
| `gemini-flash-latest` | 1.0–2.2s | ~€0.0004–0.0006 | Tracks the latest stable Flash; what the workbench defaults to. |
| `gemini-3.1-flash-lite-preview` | 0.7–1.2s | ~€0.0002 | High-volume, cost-sensitive. Less suited to nuanced branch decisions. |
| `gemini-3.1-pro-preview` | 2.5–4.5s | ~€0.0050 | High-stakes branches only (medical screening, large-deal qualification). |

Gemini's prompt caching cuts per-turn input cost by ~75% on every turn after the first. A 6-step lead-qualification form on `gemini-2.5-flash` costs roughly €0.001 per completion. Don't optimize for model cost until you've optimized for completion rate.

The library accepts any model ID string and maintains no enum — Gemini ships fast and the right model is whatever is current.

---

## 10. License & credits

MIT, public on GitHub: <https://github.com/execute008/genuiform>.

Built for the Generative UI Global Hackathon · Vienna · May 2026. The library is the constraints layer above `flutter/genui`; the workbench is the demo surface; the example is the proof. If you ship something with it, open an issue — we want to know.
