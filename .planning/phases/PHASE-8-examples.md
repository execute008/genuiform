# Phase 8 — Examples

## Goal

Build the two runnable example apps the spec demands: `freelance_qualification` (lead-gen with branching outcomes — the §13.2 hackathon killer demo) and `gymgeist_onboarding` (ladder + branch — the production-shape preview). Both live under `example/` and run with `flutter run` (Linux, macOS, iOS sim, Android emu — no web for v1 because Vertex AI direct calls leak the API key from a browser). Each example is a single `Scaffold` showing one `GenuiForm` configured per spec §11. The examples double as smoke tests during development and as the artifact judges see on Saturday.

## Acceptance criteria

- [ ] `example/pubspec.yaml` depends on `genuiform: { path: ../ }`.
- [ ] `example/lib/main.dart` shows a `MaterialApp` with a home screen that has buttons for both scenarios.
- [ ] `example/lib/scenarios/freelance_qualification.dart` exports a `freelanceQualificationForm({required LlmClient client, required String model})` returning a `GenuiForm` matching spec §11.1 exactly (fields, constraints, posture, outcomes).
- [ ] `example/lib/scenarios/gymgeist_onboarding.dart` exports `gymgeistOnboardingForm(...)` matching spec §11.2 exactly.
- [ ] LLM client is configurable via three sources, in priority order: `--dart-define=GEMINI_API_KEY=...`, `String.fromEnvironment('GEMINI_API_KEY')`, on-screen text-field fallback. Never commit a key.
- [ ] Both examples successfully reach a terminal `Outcome` when driven manually with reasonable answers (manual smoke check by the verifier — no automated test required).
- [ ] Both examples handle the no-key case with a friendly "paste your Gemini API key" panel rather than a crash.
- [ ] `example/README.md` documents how to run, where to get a Vertex AI API key, and the demo-day talking points (mirroring spec §14).

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 8.1 | Scaffold the example app: `flutter create example --template=app`, edit `pubspec.yaml` to depend on the parent package via path. Verify `flutter pub get` succeeds in `example/`. | implementer | `example/pubspec.yaml`, `example/lib/main.dart` (replace default counter app) | Phase 7 |
| 8.2 | Implement `example/lib/api_key_panel.dart` (text-field + "save" button storing in `ValueNotifier<String>`). Test: widget test asserts entering a key + pressing save fires the callback. | implementer | `example/lib/api_key_panel.dart`, `example/test/api_key_panel_test.dart` | 8.1 |
| 8.3 | Implement `example/lib/scenarios/freelance_qualification.dart` per spec §11.1. Add `Handoff` callbacks that show snackbars / dialogs for `book_call`, `send_proposal`, `decline`. | implementer | `example/lib/scenarios/freelance_qualification.dart` | 8.1 |
| 8.4 | Implement `example/lib/scenarios/gymgeist_onboarding.dart` per spec §11.2 (full ladder with nutrition branch). Handoff callbacks log to console + show a debug overlay listing the collected `FormResult`. | implementer | `example/lib/scenarios/gymgeist_onboarding.dart` | 8.1 |
| 8.5 | Wire the two scenarios into `main.dart` with a scenario picker. | implementer | `example/lib/main.dart` (extend) | 8.3, 8.4 |
| 8.6 | Add `example/README.md` with run instructions + spec §14 storyboard. | implementer | `example/README.md` | 8.5 |
| 8.7 | Verifier: `cd example && flutter pub get && flutter analyze && flutter test`. Then manually `flutter run -d macos` (or whatever platform is handy) and walk through both scenarios with a real Vertex API key from a private env var. Capture screenshots into `example/docs/`. | verifier | `example/docs/freelance.png`, `example/docs/gymgeist.png` | 8.6 |
| 8.8 | Reviewer: confirm scenario configs are byte-for-byte aligned with spec §11; confirm no API key is hard-coded; confirm `example/README.md` matches spec §14 talking points. | reviewer | — | 8.7 |
| 8.9 | Commit `feat(example): freelance qualification and gymgeist onboarding scenarios`. | git-committer | — | 8.8 |

## Files touched

- `/Users/exe008/genuiform/example/pubspec.yaml`
- `/Users/exe008/genuiform/example/lib/{main,api_key_panel}.dart`
- `/Users/exe008/genuiform/example/lib/scenarios/{freelance_qualification,gymgeist_onboarding}.dart`
- `/Users/exe008/genuiform/example/test/api_key_panel_test.dart`
- `/Users/exe008/genuiform/example/README.md`
- `/Users/exe008/genuiform/example/docs/{freelance,gymgeist}.png`

## Test strategy

- Only one widget test in this phase (the API-key panel) — the rest is manual smoke testing because the value of an example is "does it run end-to-end with real Vertex".
- The scenarios themselves are configuration code, not logic; they don't warrant unit tests beyond what Phases 1–7 already provide.

## Parallelism notes

After 8.1, tasks 8.2, 8.3, 8.4 can fan out to **three implementer agents in parallel**. 8.5 is the join. 8.6–8.9 are sequential.

