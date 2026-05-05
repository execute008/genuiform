# Phase 0 — Repo hygiene & dependencies

## Goal

Bring the bare `flutter create --template=package` scaffold up to a state where every later phase has the tooling it needs: pinned dependencies (freezed, json_serializable, build_runner, http, riverpod, mocktail, equatable), strict analysis options, working `dart run build_runner` pipeline, a CI workflow stub, and the `lib/src/` directory tree with placeholder barrel files.

## Acceptance criteria

- [ ] `flutter pub get` succeeds with all dependencies listed below.
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds (even with zero generated files yet — the runner must wire up).
- [ ] `flutter analyze` returns zero issues on the empty scaffold.
- [ ] `flutter test` runs the (still-default) test and passes.
- [ ] `lib/src/{models,strategies,llm,runtime,widgets/inputs,icons}/` directories exist (with `.gitkeep` if empty).
- [ ] `integration_test/` directory exists with a README explaining the env-var gate.
- [ ] `.github/workflows/ci.yml` skeleton runs `flutter pub get`, `flutter analyze`, `flutter test` on push.
- [ ] `analysis_options.yaml` enables `package:flutter_lints/flutter.yaml` plus `prefer_relative_imports: true`, `require_trailing_commas: true`, `avoid_dynamic_calls: true`.
- [ ] `lib/genuiform.dart` is rewritten as a barrel that exports nothing yet but is well-formed (file header comment + intentional empty body).
- [ ] `.gitignore` includes `*.g.dart`, `*.freezed.dart`, `.dart_tool/`, `build/`, `coverage/`.

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 0.1 | Update `pubspec.yaml`: add deps `freezed_annotation`, `json_annotation`, `http`, `equatable`, `meta`; dev-deps `freezed`, `json_serializable`, `build_runner`, `mocktail`, `flutter_lints`. SDK floor `^3.5.0`. Bump version to `0.1.0-dev`. | implementer | `/Users/exe008/genuiform/pubspec.yaml` | — |
| 0.2 | Tighten `analysis_options.yaml` per acceptance criteria. | implementer | `/Users/exe008/genuiform/analysis_options.yaml` | — |
| 0.3 | Scaffold directory tree and barrel files. | implementer | `/Users/exe008/genuiform/lib/genuiform.dart`, `/Users/exe008/genuiform/lib/src/models/.gitkeep`, `/Users/exe008/genuiform/lib/src/strategies/.gitkeep`, `/Users/exe008/genuiform/lib/src/llm/.gitkeep`, `/Users/exe008/genuiform/lib/src/runtime/.gitkeep`, `/Users/exe008/genuiform/lib/src/widgets/inputs/.gitkeep`, `/Users/exe008/genuiform/lib/src/icons/.gitkeep` | — |
| 0.4 | Add CI workflow. | implementer | `/Users/exe008/genuiform/.github/workflows/ci.yml` | — |
| 0.5 | Add `integration_test/README.md` documenting the `GENUIFORM_RUN_INTEGRATION=1` gate and `GEMINI_API_KEY` requirement. Add `integration_test/.gitkeep`. | implementer | `/Users/exe008/genuiform/integration_test/README.md` | — |
| 0.6 | Update `.gitignore` per acceptance. | implementer | `/Users/exe008/genuiform/.gitignore` | — |
| 0.7 | Rewrite `test/genuiform_test.dart` to a trivial placeholder asserting the package imports cleanly. | implementer | `/Users/exe008/genuiform/test/genuiform_test.dart` | 0.3 |
| 0.8 | Run `flutter pub get && dart run build_runner build && flutter analyze && flutter test`. Verify all green. | verifier | — | 0.1–0.7 |
| 0.9 | Read diff, confirm conventions and that no production code was added prematurely. | reviewer | — | 0.8 |
| 0.10 | Commit `chore(repo): scaffold deps, lints, CI, lib/src tree`. | git-committer | — | 0.9 |

## Files touched

- `/Users/exe008/genuiform/pubspec.yaml`
- `/Users/exe008/genuiform/analysis_options.yaml`
- `/Users/exe008/genuiform/lib/genuiform.dart`
- `/Users/exe008/genuiform/lib/src/**/.gitkeep` (six dirs)
- `/Users/exe008/genuiform/.github/workflows/ci.yml`
- `/Users/exe008/genuiform/integration_test/README.md`
- `/Users/exe008/genuiform/.gitignore`
- `/Users/exe008/genuiform/test/genuiform_test.dart`

## Test strategy

Phase 0 has no behavior to test. The `verifier` runs the toolchain to confirm everything wires together. The placeholder `genuiform_test.dart` exists only so `flutter test` exits 0 and CI is unblocked.

## Parallelism notes

Tasks 0.1, 0.2, 0.3, 0.4, 0.5, 0.6 are independent file edits and can fan out to up to 6 implementer agents simultaneously. 0.7 depends on 0.3. 0.8 joins all of them.

