# genuiform — Shared domain vocabulary

> Every subagent (implementer, verifier, reviewer, git-committer) MUST use these terms exactly. The four primitives are the spine of the library; conflating them is the most likely failure mode.

## The four primitives

| Primitive    | Answers                                  | Layer | Enforced by               | Bypassable by LLM? |
|--------------|------------------------------------------|-------|---------------------------|--------------------|
| `Contract`   | What data must be collected?             | Hard  | Runtime (completion check) | No                 |
| `Constraints`| What must never happen?                  | Hard  | Runtime (every turn)      | No                 |
| `Posture`    | How should the form behave?              | Soft  | LLM (prompt)              | Yes (UX-only)      |
| `Outcomes`   | Where can the form end up?               | Mixed | LLM picks, runtime routes | Routing via prompt; structure fixed |

**Hard vs soft is load-bearing.** A safety incident traces to a constraint. An ergonomics complaint traces to posture. A routing bug traces to outcomes. A missing-data bug traces to contract. Never conflate.

## Contract

- `Contract { Map<String, FieldSpec> fields; Map<String, dynamic>? exploratoryFields; }`
- `FieldSpec { Type type; bool required; String? description; List<dynamic>? enumValues; NumRange? range; int? minLength; int? maxLength; }`
- Completion: every `required: true` field has a non-null, valid value. **Runtime checks this — not the LLM.**
- `description` is prompt fuel — the LLM uses it both for what the field means and how to handle resistance.
- `exploratoryFields` is the LLM's escape hatch: discoveries that weren't predefined, never gating completion.

## Constraints

`sealed class Constraint`. Variants:

- `NeverCollect(String fieldOrTopic)`
- `NeverSkip(List<String> fieldIds)`
- `MaxSteps(int)` / `MinSteps(int)`
- `WhitelistChoices(String fieldId, List<dynamic> allowed)`
- `EscalateIf(String trigger, EscalationHandler handler)`
- `StopIf(String trigger)`
- `RequireConsent(String topic)`

Checked **every turn** by `ConstraintEnforcer`:
1. Inspect each LLM-emitted step before rendering.
2. Inspect each user answer for trigger phrases.
3. Track step count, time, other quantitative limits.

Violations override LLM output with the constraint's response.

## Posture

`Posture { int persistence; int exploration; int pacing; int skipTolerance; String voice; }` — all knobs 1–5 except `voice` (free text).

Presets: `Posture.salesDiscovery()`, `Posture.supportiveOnboarding()`, `Posture.clinicalIntake()`.

`pacing` is the most important knob. Combined with engagement signal it determines whether the form deepens through the outcome tree or offers an exit.

## Outcomes

`sealed class OutcomeNode`. Three variants:

- `Layer { String id; Contract contractDelta; Handoff handoff; OutcomeNode? next; }` — graceful exit point; if engagement is positive, continues into `next`.
- `Branch { String id; List<BranchOption> options; }` — LLM-picked split.
- `Outcome { String id; Contract contractDelta; Handoff handoff; }` — terminal; form ends.

`BranchOption { String id; String criterion; Contract? contractDelta; OutcomeNode child; }`. **`contractDelta` is nullable** — branches contribute their own fields when chosen, not just route (Spec v0.4 Fix A).

`Handoff { void Function(FormResult) onReached; }`.

### Contract composition rule (symmetric across all three node types)

The running contract at any point = merge of `contractDelta` from every node on the chosen root → current path, **including the chosen `BranchOption`**. Layers contribute when entered; branch options contribute when chosen; outcomes contribute on completion.

### Tree-shape soft guidance

> 3 levels deep or > 3 branches per node usually means product routing leaked into the form. The library doesn't enforce a depth cap, but the linter warns past those thresholds.

## Session

`Session { OutcomeNode currentNode; List<Answer> history; Map<String, dynamic> answers; Contract runningContract; SessionStatus status; EngagementSignal lastSignal; Outcome? reachedOutcome; }`

- Immutable. Each turn produces a new session.
- JSON-serializable for resume.
- `EngagementSignal { strong | weak | negative }` — computed by the LLM each turn.
- `SessionStatus { active | completed | abandoned | escalated }`.

## Strategy

```dart
abstract class Strategy {
  Stream<StepEvent> nextStep(Session session, FormConfig config);
}

sealed class StepEvent {}
class StepReady       extends StepEvent { final QuizStepSpec spec; }
class LayerComplete   extends StepEvent { final Layer layer; final bool offerExit; }
class BranchTaken     extends StepEvent { final String branchId; final String optionId; }
class OutcomeReached  extends StepEvent { final Outcome outcome; final FormResult result; }
class EscalationFired extends StepEvent { final EscalateIf rule; }
class StreamError     extends StepEvent { final Object error; }
```

Two ship in v1: `GenerativeStrategy` (every step from LLM, ~1.5–2.5s/step) and `GuidedStrategy` (LLM picks the next step from a developer-supplied catalog, ~200–400ms/step).

## LLM client

```dart
abstract class LlmClient {
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    double temperature = 0.7,
  });
}
```

- `VertexDirectClient` — API key, dev/server-side only.
- `VertexProxyClient` — Firebase Function, production.
- `FakeLlmClient` — scripted responses for tests. **Lives in `lib/src/llm/` so tests anywhere can use it; never gated behind `dev_dependency`.**

Model strings are accepted as plain `String` — no enum. See spec §9.3.

## Naming conventions enforced by reviewer

- File names: `snake_case.dart`.
- Classes: `PascalCase`. Sealed-class variants are siblings (no `XyzImpl` suffix).
- Test files mirror source path: `lib/src/foo/bar.dart` → `test/src/foo/bar_test.dart`.
- Fakes/mocks: `Fake<Name>` (preferred) or `Mock<Name>` (only when `mocktail` matters).
- Public exports go in `lib/genuiform.dart`. `lib/src/**` is private.

## Test discipline

1. **Red → green → refactor** for every implementer task.
2. Vertex AI calls are **always mocked** in `test/`. Real Vertex calls live in `integration_test/`, are gated by an env var, and are never run by `flutter test`.
3. Widget tests use `pumpWidget` + golden snapshots only where layout matters (input renderers).
4. Models with freezed get equality + JSON round-trip tests. No exceptions.

