# genuiform — Generative UI Forms for Flutter

**A Flutter library for building forms that adapt to the user as they fill them out.** Powered by Vertex AI Gemini. Forms are typed functions with a posture and a tree of outcomes — generative inside, predictable outside.

> Built for the Generative UI Global Hackathon (Vienna, May 9 2026) and freye.tech / GymGeist.

---

## TL;DR

```dart
final form = GenuiForm(
  contract: leadContract,
  constraints: [NeverCollect('payment_info'), MaxSteps(8)],
  posture: Posture.salesDiscovery(),
  outcomes: leadOutcomes,
  client: vertexClient,
  onComplete: (result) => print(result.outcome),
);
```

The form figures out which questions to ask, in what order, with what wording, and where the conversation should land — within hard constraints you specify, with the soft posture you configure.

---

## 1. Why this exists

Static multi-step forms have three failure modes:

1. **Redundancy.** A returning user answers the same questions again because the form has no memory.
2. **Wasted depth.** A confused user gets the same 15 questions as a confident one. A senior CTO with a clear brief gets the same flow as a first-time founder.
3. **Dead-end framing.** The form's wording was written once, for a generic user. It doesn't adapt to the answers it has already collected.

`genuiform` treats the form as a *conversation with a goal*. Each step is decided in context: what the user has already said, what's still unknown, how engaged they seem, and what the form is trying to learn.

---

## 2. The four primitives

The library has exactly four primitives. Each answers a different question. They compose; they don't overlap.

| Primitive | Answers | Enforced by |
|---|---|---|
| `Contract` | What data must be collected? | Runtime (completion check) |
| `Constraints` | What must never happen? | Runtime (every turn) |
| `Posture` | How should the form behave? | LLM (prompt) |
| `Outcomes` | Where can the form end up? | LLM picks, runtime routes |

The split matters because each primitive is independently testable, debuggable, and tunable. A safety incident traces to a constraint. An ergonomics complaint traces to posture. A routing bug traces to outcomes. A missing-data bug traces to contract. No conflation.

### Hard vs soft

Two of the primitives are **hard** (runtime-enforced, the LLM cannot bypass them): `Contract` and `Constraints`. Two are **soft** (LLM-interpreted): `Posture` and the routing decisions inside `Outcomes`. This division is intentional — the things that *must* happen don't depend on the LLM cooperating; the things that should *feel right* do.

---

## 3. Contract — what data must be collected

The contract defines the typed function signature of the form. It's a schema of fields the form must populate.

```dart
class Contract {
  final Map<String, FieldSpec> fields;
  final Map<String, dynamic>? exploratoryFields;  // open-ended discoveries
}

class FieldSpec {
  final Type type;                     // String, int, double, DateTime, List, Enum
  final bool required;
  final String? description;           // hint for the LLM
  final List<dynamic>? enumValues;
  final NumRange? range;
  final int? minLength;
  final int? maxLength;
}
```

Example for the hackathon demo:

```dart
final leadContract = Contract(
  fields: {
    'name':        FieldSpec(type: String,   required: true),
    'company':     FieldSpec(type: String,   required: true),
    'pain_point':  FieldSpec(type: String,   required: true,
                             description: 'The concrete problem they want solved'),
    'timeline':    FieldSpec(type: String,   required: true,
                             enumValues: ['immediate', '1-3 months', '3-6 months', '6+']),
    'budget_eur':  FieldSpec(type: int,      required: false,
                             description: 'Monthly budget in EUR, null if unwilling to share'),
    'role':        FieldSpec(type: String,   required: false,
                             enumValues: ['decision_maker', 'influencer', 'researcher']),
  },
);
```

### Completion is deterministic

The form is incomplete until every `required: true` field has a valid value. The LLM doesn't decide completion based on vibes — the runtime checks the contract. The LLM's only job is to keep asking until the contract is fillable, and to signal when no further question can extract a missing field.

### Field descriptions are prompt fuel

The `description` on each field is fed to the LLM as context. It tells the LLM both *what the field means* and *how to handle resistance*. Prompt engineering moves out of the system prompt and into the schema where it belongs.

### Exploratory fields — the escape hatch

Sometimes the conversation surfaces something valuable that wasn't predefined. A salesperson notices the prospect has a co-founder problem; a fitness coach notices the user has a competition coming up. The `exploratoryFields` map is the LLM's place to store these — typed loosely, populated only when relevant, never gating completion.

---

## 4. Constraints — what must never happen

Constraints are invariants enforced by the runtime, not the LLM. Checked every turn. Override any LLM output that violates them.

```dart
sealed class Constraint {}

class NeverCollect extends Constraint { final String fieldOrTopic; }
class NeverSkip extends Constraint { final List<String> fieldIds; }
class MaxSteps extends Constraint { final int value; }
class MinSteps extends Constraint { final int value; }
class WhitelistChoices extends Constraint { final String fieldId; final List<dynamic> allowed; }
class EscalateIf extends Constraint { final String trigger; final EscalationHandler handler; }
class StopIf extends Constraint { final String trigger; }
class RequireConsent extends Constraint { final String topic; }
```

Example for GymGeist (where some constraints have real safety implications):

```dart
final gymConstraints = [
  NeverSkip(['height_cm', 'weight_kg']),       // BMR calc — non-negotiable
  MaxSteps(15),
  EscalateIf(
    'user mentions eating disorder, purging, or extreme calorie restriction',
    handler: ReferToProfessionalSupport(),
  ),
  EscalateIf(
    'user describes injury during exercise',
    handler: ReferToMedical(),
  ),
  StopIf('user is under 16'),
];
```

### Why constraints are not just prompt instructions

You could put "never collect SSN" in the system prompt. The LLM would mostly comply. But "mostly" is not "always," and for things that matter (medical, legal, safety), `mostly` is unacceptable.

The runtime enforces constraints by:
- Inspecting each LLM-emitted step before rendering it
- Inspecting each user answer for trigger phrases
- Tracking step count, time, and other quantitative limits

If a constraint fires, the runtime overrides whatever the LLM emitted with the constraint's response.

---

## 5. Posture — how the form behaves

Posture is the soft layer. Style knobs the LLM interprets to shape the user's experience without changing what gets collected.

```dart
class Posture {
  final int persistence;     // 1-5: how hard to push when answers are vague
  final int exploration;     // 1-5: how willing to follow tangents
  final int pacing;          // 1-5: how aggressively to deepen the conversation
  final int skipTolerance;   // 1-5: how easily to accept "I don't want to answer"
  final String voice;        // free-text tone description
  
  // Common presets
  static Posture salesDiscovery() => Posture(
    persistence: 4, exploration: 2, pacing: 3, skipTolerance: 2,
    voice: 'Sovereign, curious, never desperate. Senior consultant tone.',
  );
  
  static Posture supportiveOnboarding() => Posture(
    persistence: 2, exploration: 1, pacing: 3, skipTolerance: 4,
    voice: 'Encouraging, brief, momentum-focused. Coach, not drill sergeant.',
  );
  
  static Posture clinicalIntake() => Posture(
    persistence: 5, exploration: 1, pacing: 2, skipTolerance: 1,
    voice: 'Precise, professional, non-judgmental.',
  );
}
```

### Pacing — engagement-aware depth

`pacing` is the most important knob and the one that makes the demo magical. It controls how aggressively the form pushes deeper through the outcome tree based on user engagement signals.

The LLM is prompted to read engagement from each answer:

- **Strong signals**: long answers, momentum, expressed enthusiasm, follow-up questions from user
- **Weak signals**: short answers, "idk," typing pauses, hedging, deflection
- **Negative signals**: annoyance, "is this almost done," explicit fatigue, terse answers after long ones

Combined with `pacing`:
- **Pacing 1**: stop at first complete layer, never deepen unprompted
- **Pacing 3**: continue if signals are positive, gracefully exit at first hesitation
- **Pacing 5**: push to deepest reachable outcome unless user explicitly bails

This is what static forms cannot do. A fixed flow either stops early or pushes always. Pacing-aware forms match the user's energy.

### Posture vs Constraints — the boundary

Posture knobs can be ignored by the LLM without breaking anything. If `pacing` is set to 5 but the model picks an early exit, that's bad UX, not a bug. If a constraint says `NeverCollect('payment_info')` and the model asks for a credit card, that's a runtime override, immediately. Different severity, different enforcement.

---

## 6. Outcomes — where the form can end up

Outcomes form a **tree**. Each node is one of three types:

```dart
sealed class OutcomeNode {}

/// A graceful exit point. The conversation can pause here; if engagement
/// signals are positive (per posture.pacing), the form continues into the child.
class Layer extends OutcomeNode {
  final String id;
  final Contract contractDelta;     // fields this layer adds to the running contract
  final Handoff handoff;            // what happens if the form ends here
  final OutcomeNode? next;          // null = this is the deepest layer
}

/// An LLM-picked split based on what's been learned.
class Branch extends OutcomeNode {
  final String id;
  final List<BranchOption> options;
}

class BranchOption {
  final String id;
  final String criterion;           // natural-language rule for the LLM
  final Contract? contractDelta;    // fields this option adds (nullable)
  final OutcomeNode child;
}

/// A terminal outcome. The form ends here, no further questions.
class Outcome extends OutcomeNode {
  final String id;
  final Contract contractDelta;
  final Handoff handoff;
}

class Handoff {
  final void Function(FormResult result) onReached;
}
```

### Three patterns, all expressible as trees

**Single outcome** — the simple case:
```
Outcome('lead_qualified')
```

**Branching** — mutually exclusive endings, LLM picks:
```
Branch('outcome_split', [
  BranchOption('book_call',     when: 'qualified + budget fits + decision-maker'),
  BranchOption('send_proposal', when: 'qualified + needs more info'),
  BranchOption('decline',       when: 'budget mismatch or red flag'),
])
```

**Ladder** — progressive depth, user advances if engaged:
```
Layer('account_only', next:
  Layer('with_workout_plan', next:
    Layer('with_full_setup', next: null)))
```

**Composed** — branches inside ladders, ladders inside branches:
```
Layer('account_only', next:
  Layer('with_workout_plan', next:
    Branch('nutrition_path', [
      BranchOption('full_with_meal_plan',     when: 'wants meals planned'),
      BranchOption('full_with_macro_targets', when: 'wants macros only'),
      BranchOption('full_no_nutrition',       when: 'opted out of nutrition'),
    ])))
```

### Tree depth — soft guidance

Outcome trees more than 3 levels deep usually mean product routing logic has leaked into the form. Forms collect; downstream code routes. The library doesn't enforce a depth cap, but the linter warns past 3 levels and past 3 branches per node.

### Layers always offer something useful

The temptation will be real: stack layers to capture more data while the user is around. Don't. **Each layer must produce something immediately useful to the user**, not just data for you. GymGeist's layers pass the test (workout plan = useful, nutrition plan = useful). A "tell us about your social media" layer fails.

If a layer fails this test, it's a `Branch` or shouldn't exist.

### Contract composition

The running contract at any point in the tree is the merge of all `contractDelta` values from every node on the path root → current position, *including the chosen `BranchOption`*. Layers contribute when entered. Branch options contribute when chosen. Outcomes contribute on completion. Three node types, one symmetric rule: every node on the chosen path adds what it adds.

A user who reaches `full_meal_plan` via the `with_meal_plan` branch option must satisfy all account fields (from `account_only` Layer) + workout fields (from `with_workout_plan` Layer) + meal-plan-specific fields (from the `with_meal_plan` BranchOption). A user who exits at `account_only` only needs account fields. The runtime computes the running contract dynamically as the path through the tree resolves.

---

## 7. The session

```dart
class Session {
  final OutcomeNode currentNode;
  final List<Answer> history;          // {stepId, stepSpec, answer, timestamp, engagement}
  final Map<String, dynamic> answers;  // flat lookup
  final Contract runningContract;      // composed from path through tree
  final SessionStatus status;          // active | completed | abandoned | escalated
  final EngagementSignal lastSignal;   // strong | weak | negative
  final Outcome? reachedOutcome;
}
```

Sessions are immutable; each turn produces a new session. JSON-serializable for resume. Engagement signal is computed by the LLM each turn from the answer's content and meta-signals.

---

## 8. The strategy interface

```dart
abstract class Strategy {
  Stream<StepEvent> nextStep(Session session, FormConfig config);
}

sealed class StepEvent {}
class StepReady     extends StepEvent { final QuizStepSpec spec; }
class LayerComplete extends StepEvent { final Layer layer; final bool offerExit; }
class BranchTaken   extends StepEvent { final String branchId; final String optionId; }
class OutcomeReached extends StepEvent { final Outcome outcome; final FormResult result; }
class EscalationFired extends StepEvent { final EscalateIf rule; }
class StreamError   extends StepEvent { final Object error; }
```

Two concrete strategies ship in v1:

- **`GenerativeStrategy`** — every step emitted by the LLM, constrained by `responseSchema`. Hackathon mode, high wow-factor, ~1.5–2.5s latency per step.
- **`GuidedStrategy`** — picks the next step from a developer-provided catalog of `QuizStepSpec` definitions. Production mode, ~200–400ms latency, more predictable.

A future `HybridStrategy` mixes mandatory guided steps (e.g. height/weight) with a generative tail.

---

## 9. The LLM client

Vertex AI Gemini, with two transports:

```dart
abstract class LlmClient {
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,        // see §9.3 for selection guidance
    double temperature = 0.7,
  });
}
```

### VertexDirectClient — for hackathon and dev

Calls Vertex AI directly with an API key. Never ship in a mobile app — for demos and server-side usage.

### VertexProxyClient — for production (GymGeist via Firebase Functions)

Calls a Firebase Function that proxies to Vertex with proper auth.

```dart
final client = VertexProxyClient(
  endpoint: 'https://europe-west1-gymgeist.cloudfunctions.net/genuiformProxy',
  authProvider: () async => await FirebaseAuth.instance.currentUser?.getIdToken(),
);
```

Reference Firebase Function (TypeScript) ships in `examples/firebase-proxy/`. ~30 lines.

### 9.3 Model selection

The library does not ship with an enforced default model. Consumers pick based on cost, latency, and tolerance for preview-tier rate limits. As of May 2026 the relevant options on Vertex AI are:

| Model ID | Tier | Status | Best for |
|---|---|---|---|
| `gemini-2.5-flash` | Flash | **GA**, supported through Oct 16 2026 | Conservative production default. Stable, well-documented, no preview asterisks. |
| `gemini-3-flash` | Flash | Preview | Recommended for genuiform's typical workload — Flash speed with Gemini 3 reasoning. Better at branch criteria evaluation and engagement reads. |
| `gemini-3.1-flash-lite-preview` | Flash-Lite | Preview | Highest-volume, cost-sensitive deployments. Cheapest per step, lowest latency. Less suited to nuanced branch decisions. |
| `gemini-3.1-pro-preview` | Pro | Preview | High-stakes branches only (medical screening, large-deal qualification). Overkill for routine steps; latency cost is real. |

**Notes for the build:**

- All 3-series models are currently Preview. Vertex AI guarantees at least 2 weeks notice before deprecation, but the model string can change. Production consumers should monitor the Vertex AI release notes.
- `gemini-3-pro-preview` was discontinued March 26, 2026 — do not use this string. `gemini-3.1-pro-preview` is the replacement.
- Gemini 2.5 family retirement was extended to October 16, 2026, making `gemini-2.5-flash` viable as a stable default for the next ~5 months.
- The library should accept any model ID string and not maintain a hard-coded enum — this is a fast-moving target.

**Suggested mixed strategy** (post-hackathon, when the library matures):
- `gemini-3-flash` or `gemini-2.5-flash` for routine step generation
- `gemini-3.1-pro-preview` invoked only when resolving a `Branch` with high-stakes criteria, configured per-branch via an optional `model` override on `Branch`

This last point is worth adding to v0.4 once we've measured branch decision quality — for v0.3 we keep the model string at the strategy level only.

---

## 10. The Vertex AI prompt design

### 10.1 Generative strategy system prompt

```
You are a form designer running an adaptive intake conversation.

YOUR JOB EACH TURN:
- Look at what's been collected so far.
- Look at what's still missing from the running contract.
- Look at where in the outcome tree we are.
- Decide ONE of:
  a) Ask the next question (emit a step)
  b) Offer a graceful exit (we're at a Layer boundary and engagement is weak)
  c) Resolve a Branch (we have enough to pick which path)
  d) Mark the form complete (we've reached an Outcome)

CONTRACT (running, including current path through outcome tree):
{contract_with_descriptions}

CONSTRAINTS (hard rules — never violate):
{constraints}

POSTURE:
{posture_with_explanations}

OUTCOME TREE (current position highlighted):
{outcome_tree_visualization}

CONVERSATION SO FAR:
{compact_history}

ENGAGEMENT SIGNAL FROM LAST ANSWER:
{engagement: strong | weak | negative}

INSTRUCTIONS:
- Ask ONE focused question per step. Never bundle.
- Adapt wording to the user's level and tone (per posture.voice).
- Skip what's already obvious from prior answers.
- For 'choice' and 'multiChoice', provide 2-7 options. Use icons from: {icon_registry}.
- If pacing is high and engagement is strong, push toward deeper layers.
- If pacing is low or engagement is negative, offer the current Layer's exit.
- Never invent input types. Use only: slider, choice, multiChoice, text, number, date, noneJustInformation.

Return ONLY valid JSON matching the schema. No prose, no markdown.
```

### 10.2 The responseSchema (sketch)

```json
{
  "type": "object",
  "properties": {
    "decision": {
      "type": "string",
      "enum": ["ask_step", "offer_exit", "resolve_branch", "complete"]
    },
    "step": { "$ref": "#/definitions/QuizStepSpec" },
    "branch_resolution": {
      "type": "object",
      "properties": {
        "branch_id": { "type": "string" },
        "option_id": { "type": "string" },
        "rationale": { "type": "string" }
      }
    },
    "exit_offer": { "$ref": "#/definitions/QuizStepSpec" },
    "outcome": {
      "type": "object",
      "properties": {
        "outcome_id": { "type": "string" },
        "summary": { "type": "string" }
      }
    },
    "engagement": {
      "type": "string",
      "enum": ["strong", "weak", "negative"]
    }
  },
  "required": ["decision", "engagement"]
}
```

The `decision` discriminator tells the runtime which sibling field to read. Every turn produces an engagement read regardless of decision, which feeds the next turn's prompt.

---

## 11. Examples — the four primitives in action

### 11.1 Hackathon demo: lead qualification with branching

```dart
final form = GenuiForm(
  contract: Contract(fields: {
    'name': FieldSpec(type: String, required: true),
    'company': FieldSpec(type: String, required: true),
    'pain_point': FieldSpec(type: String, required: true,
      description: 'The concrete problem they want solved'),
    'timeline': FieldSpec(type: String, required: true,
      enumValues: ['immediate', '1-3 months', '3-6 months', '6+']),
    'budget_eur': FieldSpec(type: int, required: false),
    'role': FieldSpec(type: String, required: false,
      enumValues: ['decision_maker', 'influencer', 'researcher']),
  }),
  
  constraints: [
    NeverCollect('payment_info'),
    NeverCollect('personal_id_numbers'),
    MaxSteps(8),
    EscalateIf('legal threats or hostile language', handler: PoliteEnd()),
  ],
  
  posture: Posture.salesDiscovery(),
  
  outcomes: Branch('lead_split', options: [
    BranchOption('book_call',
      criterion: 'qualified + budget fits + decision-maker',
      child: Outcome('book_call', handoff: Handoff(onReached: bookCalendly))),
    BranchOption('send_proposal',
      criterion: 'qualified + needs more info before commit',
      child: Outcome('send_proposal', handoff: Handoff(onReached: emailProposal))),
    BranchOption('decline',
      criterion: 'budget mismatch, scope mismatch, or red flag',
      child: Outcome('decline', handoff: Handoff(onReached: politeDecline))),
  ]),
);
```

### 11.2 GymGeist onboarding: ladder with branch at the deepest layer

```dart
final form = GenuiForm(
  contract: Contract(fields: {
    'email': FieldSpec(type: String, required: true),
    'name': FieldSpec(type: String, required: true),
  }),
  
  constraints: [
    NeverSkip(['height_cm', 'weight_kg']),  // only enforced past account_only layer
    MaxSteps(20),
    StopIf('user is under 16'),
    EscalateIf('eating disorder or extreme restriction',
      handler: ReferToProfessionalSupport()),
    EscalateIf('injury during exercise',
      handler: ReferToMedical()),
  ],
  
  posture: Posture.supportiveOnboarding(),  // pacing: 3, skipTolerance: 4
  
  outcomes: Layer('account_only',
    contractDelta: Contract(fields: {/* email, name only */}),
    handoff: Handoff(onReached: enterAppMinimal),
    next: Layer('with_workout_plan',
      contractDelta: Contract(fields: {
        'goals': FieldSpec(type: List, required: true),
        'fitness_level': FieldSpec(type: String, required: true),
        'equipment': FieldSpec(type: List, required: true),
        'limitations': FieldSpec(type: List, required: true),
        'preferred_days': FieldSpec(type: List, required: true),
        'workout_minutes': FieldSpec(type: int, required: true, range: NumRange(15, 240)),
        'height_cm': FieldSpec(type: int, required: true, range: NumRange(100, 250)),
        'weight_kg': FieldSpec(type: int, required: true, range: NumRange(30, 300)),
      }),
      handoff: Handoff(onReached: generateWorkoutPlanAndEnter),
      next: Branch('nutrition_path', options: [
        BranchOption('with_meal_plan',
          criterion: 'user wants concrete meals planned',
          contractDelta: Contract(fields: {
            'dietary_restrictions': FieldSpec(type: List, required: true,
              enumValues: ['vegetarian', 'vegan', 'pescatarian', 'omnivore', 'keto', 'paleo']),
            'meal_preferences': FieldSpec(type: String, required: false,
              description: 'Free-text notes on meal style, cuisines, dislikes'),
            'allergies': FieldSpec(type: List, required: false),
            'meals_per_day': FieldSpec(type: int, required: true, range: NumRange(2, 6)),
          }),
          child: Outcome('full_meal_plan', handoff: Handoff(onReached: fullSetupMeals))),
        BranchOption('with_macros_only',
          criterion: 'user wants macro targets, will plan own meals',
          contractDelta: Contract(fields: {
            'protein_target_g': FieldSpec(type: int, required: true, range: NumRange(40, 400)),
            'calorie_ceiling': FieldSpec(type: int, required: false, range: NumRange(1200, 5000)),
          }),
          child: Outcome('full_macros', handoff: Handoff(onReached: fullSetupMacros))),
        BranchOption('skip_nutrition',
          criterion: 'user opts out of nutrition entirely',
          // contractDelta: null — no extra fields collected
          child: Outcome('workout_only', handoff: Handoff(onReached: workoutOnlySetup))),
      ]))),
);
```

This single config replaces three separate flows in current GymGeist (onboarding, workout creation, nutrition creation) and adds engagement-aware exit handling that the static flows can't provide.

---

## 12. Architecture

```
genuiform/
├── lib/
│   ├── genuiform.dart                    # public exports
│   └── src/
│       ├── models/
│       │   ├── quiz_step_spec.dart       # JSON-serializable step
│       │   ├── quiz_step.dart            # runtime step (icons, validators)
│       │   ├── quiz_choice.dart
│       │   ├── contract.dart             # Contract + FieldSpec
│       │   ├── constraints.dart          # Constraint sealed class + variants
│       │   ├── posture.dart              # Posture + presets
│       │   ├── outcomes.dart             # OutcomeNode tree + Layer/Branch/Outcome
│       │   ├── session.dart              # Session + EngagementSignal
│       │   └── form_result.dart
│       ├── strategies/
│       │   ├── strategy.dart
│       │   ├── guided_strategy.dart
│       │   └── generative_strategy.dart
│       ├── llm/
│       │   ├── llm_client.dart
│       │   ├── vertex_direct_client.dart
│       │   ├── vertex_proxy_client.dart
│       │   └── schemas.dart
│       ├── runtime/
│       │   ├── constraint_enforcer.dart  # checks every turn
│       │   ├── outcome_navigator.dart    # walks the outcome tree
│       │   └── engagement_reader.dart    # signal extraction
│       ├── widgets/
│       │   ├── genui_form.dart
│       │   ├── step_renderer.dart
│       │   ├── streaming_indicator.dart
│       │   ├── inputs/                   # one widget per QuizInputType
│       │   └── dev_tools/                # opt-in demo/debug widgets
│       └── icons/
│           └── icon_registry.dart
├── example/
│   └── lib/
│       ├── main.dart
│       └── scenarios/
│           ├── freelance_qualification.dart  # hackathon demo
│           └── gymgeist_onboarding.dart      # production preview
└── pubspec.yaml
```

---

## 13. Hackathon scope (Saturday May 9, 12:00–18:00)

The library should be ~80% done before Saturday. Hackathon time is for demo polish and judging-friendly extras, not core engineering.

### 13.1 Pre-hackathon (this week)

- [x] Models: `QuizStepSpec`, `Contract`, `FieldSpec`, `Constraint` variants, `Posture`, `OutcomeNode` tree types, `Session`
- [x] Icon registry with the ~160 GymGeist icons
- [x] `LlmClient` interface + `VertexDirectClient`
- [x] `ConstraintEnforcer`, `OutcomeNavigator`, `EngagementReader`
- [x] `GenerativeStrategy` (non-streaming first, streaming if time)
- [x] All 7 input renderer widgets (port from GymGeist)
- [x] `GenuiForm` widget + `FormController`
- [x] Working example: freelance qualification with branching outcomes
- [x] Working example stub: GymGeist onboarding ladder

### 13.2 Hackathon Saturday

- [x] Polish: streaming "thinking" indicator, answer history sidebar, scenario presets
- [x] **The killer demo**: split screen, two simulated users (engaged CTO / tired founder), same form, watch it adapt depth in real time
- [x] Visual: outcome tree visualizer that lights up the active path as the form runs
- [ ] Error states, retries, edge cases the judges will poke
- [ ] 90-second pitch script
- [ ] Live demo deploy

### 13.3 Post-hackathon (week of May 11)

- [ ] `VertexProxyClient` + Firebase Function reference impl
- [ ] `GuidedStrategy` (for production mode)
- [ ] GymGeist integration: replace onboarding, then workout, then nutrition
- [ ] Session persistence (resume support)
- [ ] Pub.dev publish or keep private

---

## 14. Demo storyboard

**Setup (10s):** "Static forms ask everyone the same questions. Same depth. Same wording. Watch a generative form do better."

**Demo 1 — Adaptive depth (40s):** GymGeist onboarding ladder.
- Left split: simulated engaged user — long answers, momentum, expressed enthusiasm.
- Right split: simulated tired user — short answers, "idk," hedging.
- Same form config. Same outcome tree. Left user reaches `with_meal_plan` in 14 questions. Right user gracefully exits at `account_only` after 4. Both feel respected. Both convert.

**Demo 2 — Branching outcomes (30s):** Freelance lead qualification.
- Type as a senior CTO with clear brief: form asks 4 questions, picks `book_call`, surfaces calendar.
- Type as a confused early founder: form asks 7 questions, picks `send_proposal`, captures email.
- Type as someone with €500/month budget and €30k/month scope: form asks 3 questions, picks `decline`, politely closes.

**The pitch (20s):** "Four primitives. Contract for what to collect. Constraints for what must never happen. Posture for how it should feel. Outcomes for where it can land. Generative inside, predictable outside. Built for Flutter, powered by Vertex AI. Already shipping in two real apps next week."

---

## 15. Open questions (for the build)

- **Streaming partial JSON.** Gemini supports streaming, but partial JSON during generation is malformed. Plan: buffer until valid for v1, evaluate fragment-render later.
- **Engagement signal calibration.** The LLM's read of "engagement" is itself a soft signal. We need a fallback heuristic (answer length, response time) for when the LLM read seems wrong.
- **Branch criteria evaluation timing.** Should the LLM evaluate branch criteria after every answer, or only when the running contract is fillable? Default: only when fillable, otherwise the LLM second-guesses itself constantly.
- **Layer exit prompt wording.** When pacing + engagement triggers an exit offer, the LLM generates the exit prompt itself — but it must be a true offer, not a suggestion-disguised-as-question. Worth a posture sub-knob.
- **Branch contracts and the LLM's prompt.** When a branch hasn't been resolved yet, do we tell the LLM about *all* options' `contractDelta` fields (so it can use them in routing) or only the chosen one's after resolution? Default for v1: surface all options' deltas during routing — the field descriptions are what makes each criterion concrete and helps the LLM pick the right path.
- **Tree mutation mid-form.** Should outcomes be modifiable after the form starts? (e.g. user reveals they're a minor → snip the deep layers off). Out of scope for v1.

---

## 16. Pricing & latency budget

Indicative figures as of May 2026. All Gemini 3.x models are preview; pricing may shift before GA.

| Model | Per-step latency (streaming) | Cost per step (~1.5k in / 400 out) | Notes |
|---|---|---|---|
| `gemini-2.5-flash` | 1.0–1.8s | ~€0.0004 | Stable baseline. Reliable. |
| `gemini-3-flash` | 1.2–2.2s | ~€0.0006 (preview) | Better reasoning; mild latency premium. |
| `gemini-3.1-flash-lite-preview` | 0.7–1.2s | ~€0.0002 | Cheapest, fastest, less nuanced. |
| `gemini-3.1-pro-preview` | 2.5–4.5s | ~€0.0050 | High-stakes branch resolution only. |

A 6-step form on `gemini-3-flash`: ~€0.0036 / completion. On `gemini-3.1-flash-lite-preview`: ~€0.0012. Either is negligible at any reasonable conversion rate. Don't optimize for model cost until you've optimized for completion rate.

A common pattern: pick a Flash-tier model for routine steps, escalate to `gemini-3.1-pro-preview` only when resolving a high-stakes branch. Mixed-model deployments cost ~€0.005–0.010 per completion total.

---

## 17. License & distribution

MIT, public on GitHub. `freye-tech/genuiform`. README is this document. Pub.dev publication after the GymGeist integration validates the API.

This becomes part of the freye.tech invisible funnel: a Flutter dev who wants generative forms finds the package, sees the author, follows the freelance work. Same playbook as the Nano Framework — give the tool away, the expertise to deploy it is the product.
