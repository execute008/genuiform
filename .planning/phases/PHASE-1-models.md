# Phase 1 — Models layer

## Goal

Implement every JSON-serializable data type the library exposes — `Contract`, `FieldSpec`, the `Constraint` sealed family, `Posture`, `OutcomeNode` tree (`Layer`/`Branch`/`Outcome` + `BranchOption` + `Handoff`), `Session` (with `Answer`, `EngagementSignal`, `SessionStatus`), `QuizStepSpec`, `QuizChoice`, `QuizInputType`, `FormResult`, `NumRange`, `Message`, and the `StepEvent` sealed family. All use `freezed` + `json_serializable` so the LLM `responseSchema` and the Dart types stay in lockstep. **No Flutter imports** in this phase — pure data only. Every type ships with a JSON round-trip test.

## Acceptance criteria

- [ ] All types listed below exist as `freezed` classes with `fromJson`/`toJson`.
- [ ] `QuizInputType` is a Dart enum with `JsonEnum` annotation; values `slider, choice, multiChoice, text, number, date, noneJustInformation`.
- [ ] `Constraint` is a sealed family. Variants: `NeverCollect`, `NeverSkip`, `MaxSteps`, `MinSteps`, `WhitelistChoices`, `EscalateIf`, `StopIf`, `RequireConsent`. Each carries a `type` discriminator field for JSON.
- [ ] `OutcomeNode` is a sealed family with `Layer`, `Branch`, `Outcome` variants. JSON discriminator `node_type`. `Branch.options` is `List<BranchOption>`; `BranchOption.contractDelta` is **nullable** (Spec v0.4 Fix A).
- [ ] `Handoff` and `EscalationHandler` are typedefs over `void Function(...)` — they are **not** serialized; they live on the runtime side of each node and are rebuilt on resume by the consumer.
- [ ] `Posture` exposes the three named constructors `salesDiscovery`, `supportiveOnboarding`, `clinicalIntake` matching the spec values exactly.
- [ ] `Session.runningContract` is computed on construction by walking the path; a static helper `Session.composeRunningContract(rootOutcome, currentNode, chosenBranchOptions)` is exported and tested.
- [ ] `FieldSpec.type` is stored as `String` (e.g. `'String'`, `'int'`, `'List'`) because Dart `Type` does not serialize. A const map `kFieldTypeFromString` resolves it.
- [ ] Round-trip `Map → fromJson → toJson → Map` is identity for every freezed type.
- [ ] Equality (Dart `==`) holds across reconstructed instances (covered by freezed but tested explicitly for `Contract` and `OutcomeNode`).
- [ ] No `import 'package:flutter/...'` statements anywhere in `lib/src/models/`.
- [ ] `dart run build_runner build` is clean.
- [ ] `flutter test test/src/models/` passes.

## Tasks

All tasks pair an implementer (writes failing test then implementation) with a verifier (re-runs tests). Reviewer reads the full diff at the end. **Tasks 1.x are largely independent — fan out aggressively.**

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 1.1 | `NumRange` (min, max, both nullable) + freezed + tests. | implementer | `lib/src/models/num_range.dart`, `test/src/models/num_range_test.dart` | — |
| 1.2 | `FieldSpec` + freezed + tests (incl. enum/range/length round-trips). | implementer | `lib/src/models/field_spec.dart`, `test/src/models/field_spec_test.dart` | 1.1 |
| 1.3 | `Contract` (fields map + exploratoryFields) + tests + composition helper `Contract.merge(other)`. | implementer | `lib/src/models/contract.dart`, `test/src/models/contract_test.dart` | 1.2 |
| 1.4 | `Constraint` sealed family + per-variant freezed + JSON discriminator + tests for each variant. | implementer | `lib/src/models/constraints.dart`, `test/src/models/constraints_test.dart` | — |
| 1.5 | `Posture` + named presets + tests asserting preset numeric values exactly match spec §5. | implementer | `lib/src/models/posture.dart`, `test/src/models/posture_test.dart` | — |
| 1.6 | `Handoff` and `EscalationHandler` typedefs; documented as non-serializable. | implementer | `lib/src/models/handoff.dart`, `test/src/models/handoff_test.dart` | — |
| 1.7 | `OutcomeNode` sealed family (`Layer`, `Branch`, `Outcome`) + `BranchOption` (nullable `contractDelta`) + JSON discriminator + tree-walk helpers (`pathTo(nodeId)`, `descendants()`) + tests. | implementer | `lib/src/models/outcomes.dart`, `test/src/models/outcomes_test.dart` | 1.3, 1.6 |
| 1.8 | `QuizChoice` (id, label, description, iconName as `String?`, isTextField, configuration map) + freezed + tests. **Note: iconName is a String so the LLM can emit it; resolution to `IconData` happens in the widgets layer using the icon registry.** | implementer | `lib/src/models/quiz_choice.dart`, `test/src/models/quiz_choice_test.dart` | — |
| 1.9 | `QuizInputType` enum with `JsonEnum` + tests asserting JSON wire format matches spec §10.1 ("slider", "choice", "multiChoice", …). | implementer | `lib/src/models/quiz_input_type.dart`, `test/src/models/quiz_input_type_test.dart` | — |
| 1.10 | `QuizStepSpec` (id, title, description, inputType, initialValue as `dynamic`, configuration map, validationMessage, choices?) + freezed + JSON tests. **No Flutter imports — `iconName` is `String?` everywhere.** | implementer | `lib/src/models/quiz_step_spec.dart`, `test/src/models/quiz_step_spec_test.dart` | 1.8, 1.9 |
| 1.11 | `EngagementSignal` enum + `SessionStatus` enum + tests. | implementer | `lib/src/models/engagement_signal.dart`, `lib/src/models/session_status.dart`, plus `_test.dart` siblings | — |
| 1.12 | `Answer` (stepId, stepSpec, answer dynamic, timestamp, engagement) + tests. | implementer | `lib/src/models/answer.dart`, `test/src/models/answer_test.dart` | 1.10, 1.11 |
| 1.13 | `Session` + `Session.composeRunningContract` static helper + tests covering all three composition shapes (single Outcome, ladder, branch). | implementer | `lib/src/models/session.dart`, `test/src/models/session_test.dart` | 1.3, 1.7, 1.12 |
| 1.14 | `FormResult` (collected fields, reachedOutcome, history, status) + tests. | implementer | `lib/src/models/form_result.dart`, `test/src/models/form_result_test.dart` | 1.13 |
| 1.15 | `Message` (role: system/user/assistant; content) + tests. | implementer | `lib/src/models/message.dart`, `test/src/models/message_test.dart` | — |
| 1.16 | `StepEvent` sealed family (`StepReady`, `LayerComplete`, `BranchTaken`, `OutcomeReached`, `EscalationFired`, `StreamError`) — **not JSON-serializable** (transient runtime events) + tests. | implementer | `lib/src/models/step_event.dart`, `test/src/models/step_event_test.dart` | 1.7, 1.10, 1.14 |
| 1.17 | Update `lib/genuiform.dart` to export every public model. | implementer | `lib/genuiform.dart` | 1.1–1.16 |
| 1.18 | Run `dart run build_runner build`, `flutter analyze`, `flutter test test/src/models/`. | verifier | — | 1.17 |
| 1.19 | Reviewer pass: confirm DOMAIN vocabulary in dartdoc, no Flutter imports, sealed families correctly modelled, JSON discriminators present. | reviewer | — | 1.18 |
| 1.20 | Commit `feat(models): add Contract, Constraint, Posture, Outcome, Session, QuizStepSpec types`. | git-committer | — | 1.19 |

## Files touched

All under `/Users/exe008/genuiform/`:

- `lib/src/models/{num_range,field_spec,contract,constraints,posture,handoff,outcomes,quiz_choice,quiz_input_type,quiz_step_spec,engagement_signal,session_status,answer,session,form_result,message,step_event}.dart`
- `lib/src/models/*.freezed.dart`, `lib/src/models/*.g.dart` (generated)
- Mirroring `test/src/models/**`
- `lib/genuiform.dart` (barrel updated)

## Test strategy

- **Unit tests only.** No Flutter test bindings.
- For every freezed class: a `should round-trip JSON` test using a hand-written sample map.
- For sealed families: a parametrized test over every variant.
- For `Session.composeRunningContract`: three tests — single Outcome, three-Layer ladder, ladder + branch (mirrors spec §11.2 GymGeist tree).
- For `Posture` presets: golden-value assertions on each numeric knob to prevent regressions when copy-tweaking the voice strings.

## Parallelism notes

The dependency sub-graph inside Phase 1:

```
1.1  → 1.2 → 1.3 ─┐
1.4 (independent)  │
1.5 (independent)  ├→ 1.7 → 1.13 → 1.14 → 1.16
1.6 (independent) ─┘            ↗
1.8 → 1.10 ──────────────────┘
1.9 ↗
1.11 → 1.12 ────────────────↗
1.15 (independent)
```

Up to **5 implementer agents in parallel** at the start (1.1, 1.4, 1.5, 1.6, 1.8/1.9, 1.11, 1.15). The join points are 1.7, 1.13, 1.16. 1.17–1.20 are sequential.

