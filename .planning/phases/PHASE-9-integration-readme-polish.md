# Phase 9 — Integration tests, README, pub-readiness

## Goal

Lock the library down for distribution: a real `integration_test/` suite that hits Vertex AI end-to-end (gated by env var so CI never burns API budget), a polished top-level README that doubles as the spec for downstream consumers, dartdoc on every public API, a CHANGELOG, and a green `dart pub publish --dry-run`. Also covers spec §13.2 polish items that didn't fit into widget Phase 7: the outcome-tree visualizer, the answer-history sidebar, and a "split-screen two-user" demo widget for the killer hackathon clip.

## Acceptance criteria

### Integration tests
- [ ] `integration_test/freelance_qualification_e2e_test.dart` — drives the freelance form against real Vertex with `gemini-2.5-flash`, asserts a terminal `Outcome` is reached within `MaxSteps(8)`. Skipped unless `--dart-define=GENUIFORM_RUN_INTEGRATION=1`.
- [ ] `integration_test/gymgeist_onboarding_e2e_test.dart` — same shape, asserts `account_only` Layer is reached within 4 steps for short-answer input and `with_meal_plan` is reached within 14 for engaged input. Skipped by default.
- [ ] `integration_test/README.md` documents the env var, the API key requirement, and the cost ceiling (~€0.01 per full run).

### Polish (spec §13.2)
- [ ] `lib/src/widgets/dev_tools/outcome_tree_view.dart` — visualizes the `OutcomeNode` tree, lights up the active path. Optional widget; not part of `GenuiForm` itself, opt-in.
- [ ] `lib/src/widgets/dev_tools/answer_history_sidebar.dart` — lists `session.history` with engagement badges.
- [ ] `lib/src/widgets/dev_tools/split_user_demo.dart` — runs two `GenuiForm` instances side-by-side with different scripted answer streams (used in the demo storyboard).

### Docs
- [ ] `README.md` rewritten to match the spec verbatim — the spec IS the README per spec §17.
- [ ] Dartdoc on every public class, method, field. `dart doc .` produces zero warnings.
- [ ] `CHANGELOG.md` lists `0.1.0 – initial release` with the §13.1 feature list.
- [ ] `LICENSE` set to MIT (already present, verify).
- [ ] `pubspec.yaml` `repository`, `homepage`, `issue_tracker` fields populated to point at `https://github.com/freye-tech/genuiform`.

### Pub readiness
- [ ] `dart pub publish --dry-run` exits 0 and reports a pub.dev score of 130/160 or higher (deductions for "no example" stop being a problem after Phase 8).

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 9.1 | Implement `integration_test/freelance_qualification_e2e_test.dart` (skipped unless env gate). | implementer | `integration_test/freelance_qualification_e2e_test.dart` | Phase 8 |
| 9.2 | Implement `integration_test/gymgeist_onboarding_e2e_test.dart`. | implementer | `integration_test/gymgeist_onboarding_e2e_test.dart` | Phase 8 |
| 9.3 | Manual run with `--dart-define=GENUIFORM_RUN_INTEGRATION=1 GEMINI_API_KEY=...` against real Vertex; capture pass/fail. | verifier | — | 9.1, 9.2 |
| 9.4 | Implement `OutcomeTreeView` + tests (uses fixtures from Phase 4). | implementer | `lib/src/widgets/dev_tools/outcome_tree_view.dart`, `test/src/widgets/dev_tools/outcome_tree_view_test.dart` | Phase 7 |
| 9.5 | Implement `AnswerHistorySidebar` + tests. | implementer | `lib/src/widgets/dev_tools/answer_history_sidebar.dart`, `test/src/widgets/dev_tools/answer_history_sidebar_test.dart` | Phase 7 |
| 9.6 | Implement `SplitUserDemo` widget. Tests verify two scripted streams advance independently. | implementer | `lib/src/widgets/dev_tools/split_user_demo.dart`, `test/src/widgets/dev_tools/split_user_demo_test.dart` | Phase 7 |
| 9.7 | Add dev_tools to a "demo" route in `example/lib/main.dart`. | implementer | `example/lib/main.dart` (extend) | 9.4, 9.5, 9.6 |
| 9.8 | Rewrite `README.md` to mirror the spec. | implementer | `README.md` | — |
| 9.9 | Audit dartdoc — every public symbol gets a doc comment. Run `dart doc .` and resolve warnings. | implementer | every `lib/src/**/*.dart` (touch as needed) | 9.7 |
| 9.10 | Write `CHANGELOG.md` 0.1.0 entry. | implementer | `CHANGELOG.md` | 9.8 |
| 9.11 | Populate `pubspec.yaml` metadata. | implementer | `pubspec.yaml` | 9.10 |
| 9.12 | Run `dart pub publish --dry-run`; resolve any warnings. | verifier | — | 9.11 |
| 9.13 | Reviewer: full read-through of `README.md` against spec; sample 5 public APIs and confirm dartdoc quality. | reviewer | — | 9.12 |
| 9.14 | Commit `chore(release): prepare 0.1.0 — integration tests, dev tools, docs`. | git-committer | — | 9.13 |

## Files touched

- `/Users/exe008/genuiform/integration_test/{freelance_qualification_e2e_test,gymgeist_onboarding_e2e_test}.dart`
- `/Users/exe008/genuiform/lib/src/widgets/dev_tools/{outcome_tree_view,answer_history_sidebar,split_user_demo}.dart`
- `/Users/exe008/genuiform/test/src/widgets/dev_tools/*_test.dart`
- `/Users/exe008/genuiform/README.md`, `/Users/exe008/genuiform/CHANGELOG.md`, `/Users/exe008/genuiform/pubspec.yaml`
- Dartdoc additions across `/Users/exe008/genuiform/lib/src/**`

## Test strategy

- Integration tests run **only** with the env gate. Default `flutter test` and CI never trigger them.
- Dev-tools widget tests use `pumpWidget` + golden-free assertions (text matches, tap counts).
- README is reviewed manually; no automated test.

## Parallelism notes

Tasks 9.1, 9.2, 9.4, 9.5, 9.6, 9.8 are independent and can fan out (six implementer agents). Joins at 9.7, then sequential through 9.14.

