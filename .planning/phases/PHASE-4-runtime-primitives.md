# Phase 4 — Runtime primitives

## Goal

Implement the three pure-Dart runtime services that strategies and `FormController` lean on: `ConstraintEnforcer` (inspects every LLM-emitted step and every user answer against the active `Constraint` list), `OutcomeNavigator` (walks the `OutcomeNode` tree, computes the running contract from the chosen path, advances when a Layer is completed or a Branch is resolved), and `EngagementReader` (extracts an `EngagementSignal` from an answer with two backends: LLM-reported and a deterministic heuristic fallback per spec §15). Everything is pure Dart — no Flutter, no LLM transport — so they can be tested without any framework dependency.

## Acceptance criteria

### `ConstraintEnforcer`
- [ ] `ConstraintEnforcer(List<Constraint> constraints)` constructor.
- [ ] `EnforcementResult check(QuizStepSpec step, Session session)` — returns `Allowed`, `Replaced(QuizStepSpec replacement)`, or `Stop(reason)`.
- [ ] `EnforcementResult inspectAnswer(Answer answer, Session session)` — returns `Allowed`, `Escalated(EscalateIf rule)`, or `Stop(reason)`.
- [ ] Implements every constraint variant from Phase 1:
  - `NeverCollect` — replaces a step that targets the forbidden topic with a constraint-supplied skip step.
  - `NeverSkip` — refuses to mark form complete if any listed field is null.
  - `MaxSteps` — `Stop` when `session.history.length >= max`.
  - `MinSteps` — never short-circuits before the minimum.
  - `WhitelistChoices` — replaces choices that include disallowed values.
  - `EscalateIf` — fires `Escalated` when the answer text matches the trigger (uses `EscalationHandler`).
  - `StopIf` — `Stop` on trigger match.
  - `RequireConsent` — replaces the next step with a consent step until the topic has been consented to (consent recorded in `Session.answers` under reserved key `__consents`).
- [ ] All trigger matching is **case-insensitive substring match** for v1; document this and leave room for regex/embeddings later.

### `OutcomeNavigator`
- [ ] `OutcomeNavigator(OutcomeNode root)` constructor.
- [ ] `Contract runningContract(Session session)` — uses `Session.composeRunningContract` from Phase 1.
- [ ] `bool isLayerComplete(Layer layer, Session session)` — every `required` field in the cumulative contract up to and including `layer` has a value.
- [ ] `OutcomeNode? advance(Session session, {String? chosenBranchOption})` — returns the next node, or null if at terminal Outcome. Throws `StateError` if asked to advance from a `Branch` without `chosenBranchOption`.
- [ ] `bool isComplete(Session session)` — true when current node is an `Outcome` and its (cumulative) contract is satisfied.

### `EngagementReader`
- [ ] `EngagementSignal readFromLlm(String? llmReport)` — parses `'strong'|'weak'|'negative'`, falls back to heuristic on malformed input.
- [ ] `EngagementSignal readHeuristic(Answer current, List<Answer> history)` — pure function over answer-length, response-time delta, and presence of hedge tokens (`'idk'`, `'i guess'`, `'whatever'`). Returns `weak` when length collapses or hedge tokens appear, `strong` on long answers / quick momentum, `negative` on terse-after-long collapse.
- [ ] `EngagementSignal combine(EngagementSignal llm, EngagementSignal heuristic)` — `negative` if either says so; `weak` if either weak; `strong` only if both strong.

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 4.1 | Failing tests for each `Constraint` variant against a hand-built `Session`. | implementer | `test/src/runtime/constraint_enforcer_test.dart` | Phase 1 |
| 4.2 | Implement `ConstraintEnforcer`. | implementer | `lib/src/runtime/constraint_enforcer.dart` | 4.1 |
| 4.3 | Failing tests for `OutcomeNavigator`: single Outcome, three-Layer ladder (advance until complete), branch resolution (chosenBranchOption arg), branch with nullable contractDelta. | implementer | `test/src/runtime/outcome_navigator_test.dart` | Phase 1 |
| 4.4 | Implement `OutcomeNavigator`. | implementer | `lib/src/runtime/outcome_navigator.dart` | 4.3 |
| 4.5 | Failing tests for `EngagementReader.readFromLlm` (3 valid + malformed) and `readHeuristic` (long, short, hedge token, terse-after-long). | implementer | `test/src/runtime/engagement_reader_test.dart` | Phase 1 |
| 4.6 | Implement `EngagementReader`. | implementer | `lib/src/runtime/engagement_reader.dart` | 4.5 |
| 4.7 | Failing test for `EngagementReader.combine` truth table (3×3 = 9 cases). | implementer | `test/src/runtime/engagement_reader_test.dart` (extend) | 4.6 |
| 4.8 | Implement `combine`. | implementer | `lib/src/runtime/engagement_reader.dart` (extend) | 4.7 |
| 4.9 | Export all three classes + `EnforcementResult` sealed family from `lib/genuiform.dart`. | implementer | `lib/genuiform.dart` | 4.2, 4.4, 4.8 |
| 4.10 | Run `flutter analyze && flutter test test/src/runtime/`. | verifier | — | 4.9 |
| 4.11 | Reviewer: confirm pure Dart (no Flutter imports), confirm sealed enforcement results, confirm trigger-match behaviour is documented. | reviewer | — | 4.10 |
| 4.12 | Commit `feat(runtime): add ConstraintEnforcer, OutcomeNavigator, EngagementReader`. | git-committer | — | 4.11 |

## Files touched

- `/Users/exe008/genuiform/lib/src/runtime/{constraint_enforcer,outcome_navigator,engagement_reader}.dart`
- `/Users/exe008/genuiform/test/src/runtime/*_test.dart`
- `/Users/exe008/genuiform/lib/genuiform.dart`

## Test strategy

- Pure Dart unit tests. No widget tests. No LLM mocks needed (engagement reader tests pass strings, not LLM clients).
- For `ConstraintEnforcer`, build a `Session` fixture in `test/_fixtures/sessions.dart` (new file) so subsequent phases reuse it.
- Mirror spec §11.2 GymGeist tree as the canonical fixture for `OutcomeNavigator` tests — that single tree exercises Layer + Branch + Layer-with-branch-child + nullable `contractDelta` all at once.

## Parallelism notes

Three independent sub-chains: `ConstraintEnforcer` (4.1→4.2), `OutcomeNavigator` (4.3→4.4), `EngagementReader` (4.5→4.6→4.7→4.8). **Three implementer agents in parallel.** Single join point at 4.9.

