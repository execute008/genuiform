# Phase 7 — `GenuiForm` widget + `FormController` + step renderer

## Goal

Compose everything from Phases 1–6 into the public surface area: a `GenuiForm` widget consumers drop into their tree, a `FormController` that owns the `Session`, drives the `Strategy.nextStep` stream, and exposes `submitAnswer` / `back` / `restart`, and a `StepRenderer` that picks the right widget from Phase 6 based on `QuizStepSpec.inputType`. Plus a small `StreamingIndicator` that animates while the LLM thinks (per spec §13.2 polish list).

## Acceptance criteria

- [ ] `GenuiForm` widget signature mirrors spec §1:
  ```dart
  GenuiForm({
    required Contract contract,
    required List<Constraint> constraints,
    required Posture posture,
    required OutcomeNode outcomes,
    required LlmClient client,
    required String model,
    Strategy? strategy,           // defaults to GenerativeStrategy
    void Function(FormResult)? onComplete,
    void Function(EscalateIf)? onEscalation,
    void Function(Object)? onError,
  })
  ```
- [ ] `FormController` exposes:
  - `Stream<Session> sessions` — broadcast, emits a new session after each turn.
  - `Future<void> submitAnswer(dynamic value)` — applies the answer, advances the strategy, awaits the next event.
  - `void back()` — pops the last answer (best-effort; no LLM round-trip needed).
  - `void restart()` — resets the session.
  - `void dispose()`.
- [ ] `StepRenderer` is a stateless widget that takes `QuizStepSpec` + value + `onChanged` and dispatches to the Phase 6 widget matching `spec.inputType`. Throws `UnimplementedError` (with a clear message) if a future input type leaks through.
- [ ] `StreamingIndicator` is a tiny animated dots widget shown while `FormController` is awaiting a `StepEvent`.
- [ ] `GenuiForm` displays:
  - the current step (via `StepRenderer`),
  - a "Next" button wired to `controller.submitAnswer`,
  - a progress indicator estimating completion based on `OutcomeNavigator.runningContract` filled-required-count,
  - the streaming indicator overlay during awaits,
  - a final result panel when `OutcomeReached` fires (calls `onComplete`).
- [ ] On `EscalationFired`, `onEscalation` is invoked AND the form switches to a non-input "we'll take it from here" panel.
- [ ] Errors from the strategy stream surface via `onError` AND a retry button is shown.
- [ ] Widget tests cover: happy-path (3 scripted steps → completion), constraint escalation, error retry, restart.

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 7.1 | Failing test for `FormController.submitAnswer`: with a `FakeLlmClient` scripted to emit `StepReady → StepReady → OutcomeReached`, verify that 3 calls to `submitAnswer` complete the form and `sessions` stream emits the corresponding sessions. | implementer | `test/src/widgets/form_controller_test.dart` | Phase 5 |
| 7.2 | Implement `FormController`. | implementer | `lib/src/widgets/form_controller.dart` | 7.1 |
| 7.3 | Failing test for `StepRenderer`: each `QuizInputType` value renders the correct widget; unknown type throws. | implementer | `test/src/widgets/step_renderer_test.dart` | Phase 6 |
| 7.4 | Implement `StepRenderer`. | implementer | `lib/src/widgets/step_renderer.dart` | 7.3 |
| 7.5 | Failing test for `StreamingIndicator`: it animates and is dismissable. | implementer | `test/src/widgets/streaming_indicator_test.dart` | Phase 0 |
| 7.6 | Implement `StreamingIndicator`. | implementer | `lib/src/widgets/streaming_indicator.dart` | 7.5 |
| 7.7 | Failing widget test: full `GenuiForm` happy path with `FakeLlmClient`, asserts step appears, "Next" advances, completion calls `onComplete`. | implementer | `test/src/widgets/genui_form_test.dart` | 7.2, 7.4, 7.6 |
| 7.8 | Implement `GenuiForm`. | implementer | `lib/src/widgets/genui_form.dart` | 7.7 |
| 7.9 | Failing tests for escalation, error+retry, restart. | implementer | `test/src/widgets/genui_form_test.dart` (extend) | 7.8 |
| 7.10 | Make those tests pass. | implementer | `lib/src/widgets/genui_form.dart` (extend) | 7.9 |
| 7.11 | Update `lib/genuiform.dart` to export `GenuiForm`, `FormController`, `StepRenderer`, `StreamingIndicator`. | implementer | `lib/genuiform.dart` | 7.10 |
| 7.12 | `flutter analyze && flutter test test/src/widgets/`. | verifier | — | 7.11 |
| 7.13 | Reviewer: confirm public API matches spec §1 / §11 examples; no leakage of `Session` in the public widget API except through `FormController`. | reviewer | — | 7.12 |
| 7.14 | Commit `feat(widgets): add GenuiForm, FormController, StepRenderer, StreamingIndicator`. | git-committer | — | 7.13 |

## Files touched

- `/Users/exe008/genuiform/lib/src/widgets/{genui_form,form_controller,step_renderer,streaming_indicator}.dart`
- `/Users/exe008/genuiform/test/src/widgets/*_test.dart`
- `/Users/exe008/genuiform/lib/genuiform.dart`

## Test strategy

- Widget tests use `FakeLlmClient` exclusively.
- For animated assertions on `StreamingIndicator`, use `tester.pump(const Duration(milliseconds: 300))` and `tester.pumpAndSettle()`.
- Use `mocktail` to spy on `onComplete`, `onEscalation`, `onError` callbacks.
- Reuse session fixtures from Phase 4's `test/_fixtures/sessions.dart`.

## Parallelism notes

Inside Phase 7, three sub-chains can run in parallel after Phase 5/6 land: `FormController` (7.1→7.2), `StepRenderer` (7.3→7.4), `StreamingIndicator` (7.5→7.6). They join at 7.7 (`GenuiForm` widget test) which is necessarily sequential.

Phase 7 is the **first single-threaded join point** of the project. Plan accordingly: do not start Phase 7 until both 5 and 6 are signed off.

