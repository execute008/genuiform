# genuiform_workbench — Spec for Claude Code

**Live code editor + form preview for the genuiform library.** Built as a Flutter Web app that ships alongside the genuiform repo. Designed to be *the* hackathon demo surface: judges sit at the laptop, edit the form definition on the left, watch the form rebuild on the right. Same interaction whoever is sitting there — engineer, designer, judge.

> Companion to https://github.com/execute008/genuiform — must consume the library directly, no parallel implementations.

---

## 1. The constraint that shapes everything

**Flutter Web cannot compile Dart at runtime.** There is no in-browser Dart compiler. Any solution that pretends "the user is editing real Dart and we compile it live" is either lying or requires a backend running `dart analyze` / hot reload tricks — both of which can fail on stage and neither of which we have time to build before May 9.

The honest design: **the editor accepts a constrained DSL that *looks* like Dart and parses to genuiform types.** The user sees Dart-shaped syntax with full highlighting; under the hood, the workbench runs a hand-written parser that produces `Contract`, `Constraints`, `Posture`, and `OutcomeNode` instances. Anything outside the DSL grammar is a parse error displayed inline.

What this gets us:
- Pure Flutter Web build, no backend, deploys to GitHub Pages or Firebase Hosting in 30 seconds
- Zero runtime risk during demo — no compilation, no network beyond Vertex AI calls
- Looks indistinguishable from real Dart to a judge watching over your shoulder
- Works offline (except for the actual LLM calls)

What this costs us:
- The DSL is a strict subset of Dart. No conditionals, no helpers, no imports. Just literal config trees.
- If the user wants a custom `EscalationHandler`, they pick from a fixed enum — they can't write code for it.
- The parser must produce clear error messages or the demo dies.

**This is the right tradeoff.** Document it visibly in the workbench (a small "DSL editor" badge under the editor pane), don't try to hide it.

---

## 2. What the workbench is, in one screen

```
┌─────────────────────────────────────────────────────────────────────────┐
│ genuiform workbench                              [Scenario ▾] [Run] [↺] │
├─────────────────────────────────────┬───────────────────────────────────┤
│                                     │                                   │
│  // Edit the form definition        │   ┌───────────────────────────┐  │
│  final form = GenuiForm(            │   │  What's your company?     │  │
│    contract: Contract(fields: {     │   │                           │  │
│      'name': FieldSpec(...),        │   │  [ Acme Industries     ]  │  │
│      'company': FieldSpec(...),     │   │                           │  │
│      ...                            │   │            [ Continue ]   │  │
│    }),                              │   └───────────────────────────┘  │
│    constraints: [                   │                                   │
│      MaxSteps(8),                   │   ───────────────────────────     │
│      NeverCollect('payment_info'),  │   Engagement: strong              │
│    ],                               │   Step 2 of ~6                    │
│    posture: Posture.salesDiscovery()│   Path: Branch(lead_split)        │
│    outcomes: Branch('lead_split', [ │                                   │
│      ...                            │   ───────────────────────────     │
│    ]),                              │   Collected:                      │
│  );                                 │   • name: "Oskar Freye"           │
│                                     │   • company: <pending>            │
│                                     │                                   │
│  ✓ parsed cleanly                   │                                   │
│                                     │                                   │
└─────────────────────────────────────┴───────────────────────────────────┘
```

**Left pane (50%):** Code editor with syntax highlighting, line numbers, error squiggles, parse status footer.

**Right pane (50%):** The actual genuiform widget rendering, with a debug strip below showing engagement signal, step count, current outcome tree position, and collected answers so far.

**Top bar:** Scenario picker (preset configs), Run button (reparse + restart form), Reset button.

The layout is split-screen on desktop (≥900px), stacked on mobile (editor collapsible). Mobile is a nice-to-have — judges will use desktop.

---

## 3. The DSL

The DSL is a strict subset of Dart that the workbench's parser understands. Goal: a developer reading the editor sees something that looks identical to the genuiform README. The parser is permissive about whitespace and comments, strict about structure.

### 3.1 Grammar (informal)

```
form         := "final form = GenuiForm(" args ");"
args         := contract "," constraints "," posture "," outcomes ","?

contract     := "contract:" "Contract(fields:" "{" field* "}" ")"
field        := stringLit ":" "FieldSpec(" namedArg+ ")" ","?

constraints  := "constraints:" "[" constraint* "]"
constraint   := constraintCtor "(" args? ")" ","?
constraintCtor := "NeverCollect" | "NeverSkip" | "MaxSteps" | "MinSteps"
                | "WhitelistChoices" | "EscalateIf" | "StopIf" | "RequireConsent"

posture      := "posture:" (postureLiteral | posturePreset)
postureLiteral := "Posture(" namedArg+ ")"
posturePreset  := "Posture." identifier "()"

outcomes     := "outcomes:" outcomeNode
outcomeNode  := layer | branch | outcome
layer        := "Layer(" stringLit "," "contractDelta:" contractInline? ","
                "next:" outcomeNode ")"
branch       := "Branch(" stringLit "," "options:" "[" branchOption+ "]" ")"
branchOption := "BranchOption(" stringLit ","
                "criterion:" stringLit ","
                ("contractDelta:" contractInline ",")?
                "child:" outcomeNode ")"
outcome      := "Outcome(" stringLit "," "contractDelta:" contractInline? ","
                "handoff:" handoffStub ")"

handoffStub  := "Handoff(onReached:" identifier ")"
              // identifier resolves to a registered demo handoff —
              // see §3.4 for the registry

namedArg     := identifier ":" value
value        := stringLit | numLit | boolLit | listLit | mapLit | typeRef | enumLit
```

A reference Dart-like grammar fragment is fine; the parser doesn't need to be Turing-complete or even strictly Dart-compatible. **It just needs to recognize the genuiform config shapes.**

### 3.2 What the DSL does NOT support

- Variable bindings (no `final x = ...; ... x ...`) — values are inline literals only
- Conditional expressions, loops, function definitions
- Imports, types beyond the genuiform set
- Custom handoff/escalation closures — these come from a registry (see §3.4)
- String interpolation — plain string literals only

If the parser encounters anything outside the grammar, it reports a precise error: `Line 14: unexpected token 'if'. The workbench DSL doesn't support conditionals — use scenario presets instead.`

### 3.3 What the DSL DOES support beyond bare grammar

Quality-of-life sugar that makes the demo feel real:

- **Trailing commas everywhere** — Dart-idiomatic
- **Single-line comments** (`//`) and block comments (`/* */`)
- **Posture presets**: `Posture.salesDiscovery()`, `Posture.supportiveOnboarding()`, `Posture.clinicalIntake()` resolve to the actual library presets
- **Type literals**: `String`, `int`, `double`, `DateTime`, `List`, `bool` for `FieldSpec.type`
- **`NumRange(min, max)`** literal, since `FieldSpec` uses it

### 3.4 The handoff registry

Real Handoff callbacks are Dart functions; the DSL can't have those. Instead, the workbench ships a **registry of named handoffs** that simulate plausible end-states:

```dart
const handoffRegistry = {
  'bookCalendly':       SimulatedHandoff(label: 'Book a call', icon: 'calendar'),
  'emailProposal':      SimulatedHandoff(label: 'Send proposal', icon: 'mail'),
  'politeDecline':      SimulatedHandoff(label: 'Politely decline', icon: 'door'),
  'enterAppMinimal':    SimulatedHandoff(label: 'Enter app', icon: 'home'),
  'generateWorkoutPlan':SimulatedHandoff(label: 'Generate workout plan', icon: 'dumbbell'),
  'fullSetupMeals':     SimulatedHandoff(label: 'Generate full setup with meals', icon: 'utensils'),
  'fullSetupMacros':    SimulatedHandoff(label: 'Generate setup with macros', icon: 'scale'),
  'workoutOnlySetup':   SimulatedHandoff(label: 'Workout-only setup', icon: 'check'),
  // ...add more as scenarios need them
};
```

When the form completes, instead of executing real navigation, the workbench shows a "Handoff fired: bookCalendly — 'Book a call'" toast in the form pane. Same for escalations — `EscalateIf(handler: ReferToProfessionalSupport())` triggers a simulated escalation card.

The DSL accepts `Handoff(onReached: bookCalendly)` where `bookCalendly` is a registry key. If the user types an unknown identifier, parse error: `Line 23: unknown handoff 'bookFoo'. Available: bookCalendly, emailProposal, politeDecline, ...`

---

## 4. Architecture

```
genuiform_workbench/
├── lib/
│   ├── main.dart                       # entry, theme, routing
│   ├── src/
│   │   ├── editor/
│   │   │   ├── editor_pane.dart        # CodeMirror-style widget
│   │   │   ├── dart_highlighter.dart   # syntax highlighting rules
│   │   │   ├── error_overlay.dart      # inline squiggles + tooltip
│   │   │   └── line_numbers.dart
│   │   ├── parser/
│   │   │   ├── lexer.dart              # tokenizer
│   │   │   ├── parser.dart             # recursive-descent parser
│   │   │   ├── ast.dart                # parsed node types
│   │   │   ├── builder.dart            # AST → genuiform objects
│   │   │   └── parse_error.dart        # error type with line/col
│   │   ├── preview/
│   │   │   ├── form_preview.dart       # right pane wrapping GenuiForm
│   │   │   ├── debug_strip.dart        # engagement, step count, path
│   │   │   ├── handoff_toast.dart
│   │   │   └── escalation_card.dart
│   │   ├── scenarios/
│   │   │   ├── scenario.dart           # data class
│   │   │   ├── scenario_picker.dart
│   │   │   ├── lead_qualification.dart # the freelance demo
│   │   │   ├── gymgeist_onboarding.dart
│   │   │   ├── newsletter_signup.dart  # tiny single-outcome example
│   │   │   └── medical_intake.dart     # heavy-constraints example
│   │   ├── registry/
│   │   │   ├── handoff_registry.dart   # see §3.4
│   │   │   └── escalation_registry.dart
│   │   ├── llm/
│   │   │   └── workbench_llm_client.dart
│   │   │       # wraps VertexDirectClient with workbench-friendly
│   │   │       # error handling and dev-mode features
│   │   ├── persistence/
│   │   │   └── url_state.dart          # encode current scenario+code in URL hash
│   │   └── shell/
│   │       ├── app_shell.dart          # top bar, split layout
│   │       ├── split_view.dart         # resizable divider
│   │       └── theme.dart
├── assets/
│   └── scenarios/                       # bundled .gendsl files
└── pubspec.yaml
```

**Dependencies to add:**

- `flutter_highlight` or `re_editor` or `code_text_field` for the editor surface (pick whichever has best Flutter Web support as of build day — check pub.dev rankings)
- `genuiform` (path dependency on `../`)
- `petitparser` is *optional* — the DSL is small enough to hand-write a recursive-descent parser, which is more debuggable for a hackathon. Recommend hand-writing.

---

## 5. Build order (Claude Code, follow this)

These are the Claude Code build phases. Each phase produces a runnable workbench at progressively higher fidelity. Do not skip phases — the order is chosen so something works at every checkpoint.

### Phase 0 — Repo setup (15 min)

- [ ] Create `workbench/` directory at the repo root (sibling to `lib/` and `example/`)
- [ ] `flutter create --platforms=web workbench`
- [ ] In `workbench/pubspec.yaml`, add `genuiform: { path: ../ }` as dependency
- [ ] Add to root `.github/workflows/` a deploy-to-pages step that builds `workbench/build/web` (don't activate yet, just have the file ready)
- [ ] Confirm `flutter run -d chrome` from `workbench/` works with a "Hello workbench" screen

### Phase 1 — Static split layout with hardcoded form (45 min)

Goal: see a form running in the right pane, with placeholder code text in the left pane. No parsing yet, no editing yet.

- [ ] `app_shell.dart`: Top bar with title, scenario dropdown (just visual), Run button (just visual)
- [ ] `split_view.dart`: 50/50 resizable horizontal split, snaps back to 50/50 on double-click of divider
- [ ] Left pane: read-only `Text` widget showing the lead_qualification scenario as a hardcoded string
- [ ] Right pane: hardcoded `GenuiForm` with the lead_qualification config in Dart, wired to a real `VertexDirectClient` reading API key from `--dart-define=VERTEX_API_KEY=...`
- [ ] Below the form: debug strip showing step number, engagement signal (subscribe to session updates from `FormController`), current outcome path
- [ ] Confirm running through the form end-to-end works

This phase verifies the workbench can host a real form. The editor is fake.

### Phase 2 — Read-only editor with syntax highlighting (30 min)

- [ ] Replace the `Text` widget with a real code editor widget (`re_editor` recommended; if it doesn't build for Flutter Web cleanly, fall back to `code_text_field` or a simple custom `TextField` with a syntax highlighter overlay)
- [ ] Apply Dart-syntax highlighting using whichever package the editor supports
- [ ] Show line numbers in a left gutter
- [ ] Editor is **read-only** in this phase — set `readOnly: true`
- [ ] Confirm code looks like Dart in a code editor

### Phase 3 — The parser (90–120 min)

This is the load-bearing piece. Get the unit tests right *first*.

- [ ] `lexer.dart`: Tokenize the DSL. Tokens: `IDENT`, `STRING`, `NUMBER`, `BOOL`, `LBRACE`, `RBRACE`, `LBRACK`, `RBRACK`, `LPAREN`, `RPAREN`, `COMMA`, `COLON`, `DOT`, `EOF`. Strip comments. Track line/column on every token for error reporting.
- [ ] `ast.dart`: Define AST node types: `FormNode`, `ContractNode`, `FieldSpecNode`, `ConstraintNode`, `PostureNode`, `OutcomeNode` variants (`LayerNode`, `BranchNode`, `BranchOptionNode`, `OutcomeTerminalNode`).
- [ ] `parser.dart`: Recursive-descent parser following the grammar in §3.1. Each parse method returns an AST node or throws a `ParseError(line, col, message, hint)`.
- [ ] `builder.dart`: Walk the AST, produce real genuiform objects. Resolves handoff identifiers against the registry.
- [ ] **Unit tests** in `test/parser_test.dart`: parse each of the four scenarios from §6, assert the resulting object equals a hand-written reference. This is non-negotiable — the parser must be tested before wiring to the editor.
- [ ] Error tests: assert that `Layer(` without an id produces "Line 12: expected string literal as first arg to Layer". Test ~10 common error cases.

When this phase is done, you can call `parseDsl(String code) → ParseResult { form: GenuiForm?, errors: [ParseError] }` from anywhere in the workbench. Phase 4 wires it up.

### Phase 4 — Live parse-and-rebuild (60 min)

- [ ] Make the editor writable (`readOnly: false`)
- [ ] Debounce edits (250ms) and re-parse on every change
- [ ] Display parse status in editor footer: green check + "parsed cleanly" or red X + "3 errors"
- [ ] Render parse errors as inline squiggles in the editor (red underline) with a tooltip on hover
- [ ] On successful parse, **rebuild the right pane's `GenuiForm`** with the new config, resetting any in-progress session
- [ ] Add a Run button that explicitly resets the form even if the code didn't change
- [ ] Confirm: typing a bad value into a `MaxSteps` arg shows a squiggle. Fixing it makes the form rebuild within 250ms.

### Phase 5 — Scenario presets and URL state (45 min)

- [ ] `scenarios/` folder: each scenario is `{id, name, description, dsl: String}`. Bundle ~4 scenarios (see §6).
- [ ] Wire the top-bar dropdown to load a scenario into the editor when picked
- [ ] On any code change, encode the current code into the URL hash (gzipped + base64) so users can share workbench URLs
- [ ] On load, if URL has a hash, decode it into the editor instead of the default scenario
- [ ] Confirm: pick "GymGeist onboarding" from the dropdown → editor populates → form rebuilds → URL updates

### Phase 6 — Demo polish (Saturday morning if needed)

- [ ] Animations: when the form rebuilds, fade the right pane briefly (not a full clear — just a tint pulse)
- [ ] When the outcome tree path changes, animate the debug strip's path indicator
- [ ] Handoff toasts (§3.4) with icon + label appear when the form completes
- [ ] Escalation cards appear in the form pane when an `EscalateIf` fires
- [ ] Add a small "About this workbench" link in the corner — opens a modal explaining the DSL constraint (§1)
- [ ] Confirm the demo flow from §7 works end-to-end without errors
- [ ] Build for production: `flutter build web --release --dart-define=VERTEX_API_KEY=...` (key is baked in for the demo — the API key has its own scoped Vertex permissions; rotate after hackathon)
- [ ] Deploy to Firebase Hosting or GitHub Pages

---

## 6. Bundled scenarios (live in `assets/scenarios/`)

### 6.1 `lead_qualification.gendsl` (the hackathon hero)

The freelance lead qualification example from genuiform README §11.1, written in DSL form. Outcome is a `Branch` with three options: `book_call`, `send_proposal`, `decline`.

### 6.2 `gymgeist_onboarding.gendsl` (the depth-adaptive demo)

The GymGeist onboarding ladder from README §11.2: `account_only → with_workout_plan → Branch(nutrition_path)`. This is the visceral one for showing pacing/engagement.

### 6.3 `newsletter_signup.gendsl` (the simple one)

Two fields, no constraints, single outcome. Exists so judges who want to see "what's the simplest thing" have a clean answer.

```dart
final form = GenuiForm(
  contract: Contract(fields: {
    'email': FieldSpec(type: String, required: true,
      description: 'Email for newsletter delivery'),
    'frequency_preference': FieldSpec(type: String, required: false,
      enumValues: ['daily', 'weekly', 'monthly'],
      description: 'How often the user wants to hear from us'),
  }),
  constraints: [MaxSteps(3)],
  posture: Posture(
    persistence: 1, exploration: 1, pacing: 1, skipTolerance: 5,
    voice: 'Brief, friendly, respectful of the user\'s time.',
  ),
  outcomes: Outcome('subscribed',
    contractDelta: Contract(fields: {}),
    handoff: Handoff(onReached: enterAppMinimal)),
);
```

### 6.4 `medical_intake.gendsl` (the constraint-heavy one)

Demonstrates `EscalateIf`, `StopIf`, `RequireConsent`. Shows judges that the library handles serious-domain forms — not just sales toys.

---

## 7. Demo flow (use this for the pitch)

**[10s — setup]** "This is genuiform. Static forms ask everyone the same questions. Let me show you what generative does differently."

**[15s — show lead_qualification]** Pick scenario from dropdown. Form appears on right. "Same form config. I'm going to act like two different prospects."

**[30s — Demo run 1]** Type as senior CTO with clear brief. Form asks 4 questions, picks `book_call`. Toast: "Handoff fired: Book a call". 

**[20s — Demo run 2]** Hit Run. Type as confused founder. Form asks 7 questions, picks `send_proposal`. Toast: "Handoff fired: Send proposal".

**[30s — Live edit]** "Now watch this." Click into the editor. Change `MaxSteps(8)` to `MaxSteps(3)`. Hit Run. Type same CTO prompt. Form completes in 3 questions instead of 4. "I just rewrote the form's behavior live. No deploy. No rebuild. The form is the config."

**[15s — Switch scenario]** Pick `gymgeist_onboarding`. Different form appears. "Same library, different config, totally different product. This is the same DSL that runs in production."

**[20s — The pitch]** "Four primitives. Contract for what to collect. Constraints for what must never happen. Posture for how it should feel. Outcomes for where it can land. Generative inside, predictable outside. Already shipping."

Total: ~2 minutes. Practice the live edit step three times before Saturday — that's the one moment where things can go wrong.

---

## 8. Failure modes to guard against

These are the things that will go wrong on stage if not addressed:

- **Vertex API rate limit during demo.** Have a local mock LLM client behind a `--dart-define=USE_MOCK=true` flag. If Vertex flakes, switch and continue. Mock just returns canned step JSON for the lead_qualification scenario.
- **Parser crash on malformed input.** Wrap parser entry point in try/catch, always render *something* in the right pane — last-known-good form if parse fails entirely.
- **Form gets stuck mid-step.** Run button must reset the form unconditionally, including aborting any in-flight LLM stream.
- **Code editor performance on long files.** All bundled scenarios are <100 lines. Don't add a "load any file" feature — keep the surface area small.
- **Mobile layout.** Workbench is a desktop demo. On mobile, show a "best viewed on desktop" banner with collapsible editor below the form.

---

## 9. What's NOT in scope

To keep the build tractable for ~2–3 days of work:

- Save/load to local storage (URL hash is enough)
- Multiple files / imports in the DSL
- Theme switching (one good dark theme, ship it)
- Authentication (workbench is a public demo, not a SaaS)
- Backend (no Firebase Functions, no proxy — direct Vertex via API key for the demo)
- Server-side rendering / SSR
- A "form runner" that executes the form headlessly without the UI — interesting but not for v1

---

## 10. Success criteria

The workbench is done when:

- [ ] All four bundled scenarios load, parse, and run to completion without manual intervention
- [ ] Editing any field in any scenario reparses within 300ms and rebuilds the form
- [ ] At least one parse error type is visibly demonstrated (squiggle + tooltip)
- [ ] The hackathon demo flow (§7) executes in under 3 minutes without any code-level interventions
- [ ] The deployed URL works on a fresh browser with no setup
- [ ] The mock LLM client works as a fallback if Vertex is unavailable

---

## 11. After the hackathon

Light list of things to ship post-Saturday:

- Add a third pane: the LLM prompts being sent each turn (great for tutorial value)
- Export a parsed config back to real Dart code (one-way bridge from DSL → production code)
- Embed the workbench iframe-style in the genuiform README as a live "try it" widget
- A second editor mode that edits JSON directly (for users who hit DSL ceiling)

### 11.1 Real Dart compilation — upgrade paths

The DSL parser (§1) is a deliberate hackathon-scope choice, not the only architecture. Two real paths exist to upgrade the workbench to *actual* in-browser Dart editing:

**Self-host `dart_services`.** DartPad's backend (`pkgs/dart_services` in the open-source dart-pad repo) compiles Dart→JS server-side. Deploy it to a Cloud Run instance or Firebase Function, point the workbench at the endpoint, replace the parser with a thin RPC client. Estimated effort: ~2–3 days. Tradeoffs: now you have a backend to maintain, but the workbench becomes a real Dart editor with real type errors, real autocomplete potential, and real package support.

**Zapp.run's compiler SDK.** Zapp ships `https://cdn.zapp.run/compiler.min.js` — a pure browser-side Dart compiler with `loadFileSystem`, `runPubGet`, `run`, and `mount` methods. No backend needed. As of May 2026 the integration API is in private beta — contact `oss@invertase.io`. If access is granted, this is the cleanest upgrade: replace the parser with `compiler.run()`, keep everything else. Tradeoffs: dependent on a third-party CDN, but no infra to maintain.

**Why neither for the hackathon:** Both options either require a deployed backend (deployment risk on stage) or third-party access we don't have yet. The DSL gives us the same demo-feel with zero stage risk and zero new infrastructure. After Saturday, when there's no stage and we have time to negotiate access, swap the parser for one of these.

**What does NOT work:** embedding `dartpad.dev` as an iframe. DartPad runs Dart in its own isolated iframe sandbox; the compiled code cannot reach into the parent workbench's runtime to drive the genuiform widget. Iframe embedding is fine for "Dart playground next to a form" but breaks the workbench's core premise — that edits on the left rebuild *the actual library's form* on the right.

---

## 12. The prompt to give Claude Code

Paste this exact text:

> I have a Flutter library at the repo root called `genuiform` (see README.md) — a generative-UI form library powered by Vertex AI. I need you to build a companion Flutter Web app called the **workbench** in a new `workbench/` directory at the repo root.
>
> The workbench is a split-screen live code editor: left pane is a Dart-shaped DSL editor for genuiform configs, right pane is the actual `GenuiForm` rendering and updating live as the user edits. It will be the main demo for the Generative UI Hackathon on May 9 2026.
>
> Read the spec at `WORKBENCH_SPEC.md` (this document) end-to-end before writing code. Follow the build order in §5 phase by phase — do not skip phases, do not jump ahead. Confirm each phase's success criteria before moving to the next.
>
> Critical constraints:
> - The editor is a DSL parser, NOT a real Dart compiler. See §1 for why.
> - The library is at `../` from the workbench — use a path dependency.
> - Vertex API key comes from `--dart-define=VERTEX_API_KEY=...`. Never hardcode it.
> - Pure Flutter Web, no backend.
>
> When you finish a phase, run the workbench in Chrome and verify the success criteria for that phase. Report what's working before starting the next phase. If you hit a design decision the spec doesn't cover, ask before guessing.

---

*Spec v0.1 — May 5 2026, Vienna*
*Companion to genuiform v0.4. Built for the Generative UI Global Hackathon, May 9 2026.*
