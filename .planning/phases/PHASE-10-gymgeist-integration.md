# Phase 10 — GymGeist integration (Stage 2, post-hackathon)

## Goal

Replace the static onboarding flow in `gymgeist` with `GenuiForm` on a separate git worktree, behind a feature flag, validating the library against a real production app. This is **Stage 2** per the original brief — out of scope for the hackathon, in scope for the week of May 11. The library must not be modified during this phase except for bug fixes that surface from real-app integration; any structural changes need a new genuiform release first.

## Acceptance criteria

- [ ] A new git worktree exists at `/Users/exe008/gymgeist-genuiform/` (or `/Users/exe008/gymgeist/.worktrees/genuiform/` — implementer's call) on a branch `feat/genuiform-onboarding`.
- [ ] `gymgeist/pubspec.yaml` (on that branch) adds `genuiform: { path: ../genuiform }` (or git ref once published).
- [ ] A new file `gymgeist/lib/features/auth/presentation/genui_onboarding_screen.dart` instantiates `GenuiForm` with the spec §11.2 ladder + nutrition branch.
- [ ] A feature flag `useGenerativeOnboarding` in `gymgeist/lib/shared/feature_flags.dart` (or similar — implementer surveys the existing flag pattern; do not invent if one exists) toggles between the old `MultiStepQuiz` flow and the new `GenuiForm` flow.
- [ ] The `Handoff` callbacks call into the existing GymGeist services (workout-plan generator, nutrition-plan generator, account creation) — same downstream code paths as the current static flow.
- [ ] `LlmClient` is `VertexProxyClient` pointing at the existing GymGeist Firebase project (NOT `VertexDirectClient` — gymgeist is a shipped mobile app).
- [ ] **Phase 10 forces Phase 9.5 (or new Phase 11): a real `VertexProxyClient` implementation.** Track this as the first dependency.
- [ ] The old `MultiStepQuiz` flow is preserved unchanged behind the flag — zero regression risk for existing users.
- [ ] Manual smoke test on iOS sim and Android emu confirms the new flow reaches the same downstream state as the old one.
- [ ] No widget tests required in gymgeist for the new flow beyond what genuiform already covers; one integration test confirms the feature flag toggles correctly.

## Pre-Phase work (these go into a new Phase 10a or get folded back into Phase 3)

- [ ] **`VertexProxyClient` real implementation** — currently a stub from Phase 3. Need: HTTP POST to a Firebase Function endpoint, Firebase auth header, error mapping. Tests use `MockClient`. Must land before Phase 10 starts.
- [ ] **Reference Firebase Function** in `genuiform/examples/firebase-proxy/index.ts` (~30 lines per spec §9). Deployed to a sandbox project for testing.
- [ ] **Session persistence** — spec §13.3 mentions resume support. Phase 10 may need this if onboarding gets interrupted (e.g. user kills app mid-flow). Decision deferred until first user-test feedback.

## Tasks (sketch — refined when this phase actually starts)

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 10.0 | Real `VertexProxyClient` implementation + deployment of reference Firebase Function. | implementer | `lib/src/llm/vertex_proxy_client.dart`, `examples/firebase-proxy/index.ts` | Phase 9 done |
| 10.1 | Create git worktree, branch, and survey gymgeist feature-flag conventions. | implementer | `/Users/exe008/gymgeist-genuiform/` worktree, `gymgeist/lib/shared/feature_flags.dart` (or existing equivalent) | 10.0 |
| 10.2 | Add `genuiform` dependency to gymgeist pubspec on the new branch. | implementer | `gymgeist/pubspec.yaml` (worktree) | 10.1 |
| 10.3 | Implement `GenuiOnboardingScreen` wrapping `GenuiForm` with the §11.2 config and gymgeist's existing handoff services. | implementer | `gymgeist/lib/features/auth/presentation/genui_onboarding_screen.dart` | 10.2 |
| 10.4 | Wire the feature flag in the gymgeist routing layer to choose between `MultiStepQuiz` and `GenuiOnboardingScreen`. | implementer | wherever onboarding is currently routed in `gymgeist/lib/features/auth/` | 10.3 |
| 10.5 | One integration test in gymgeist confirms the flag toggles routing. | implementer | `gymgeist/integration_test/genui_onboarding_flag_test.dart` | 10.4 |
| 10.6 | Manual smoke on iOS sim + Android emu. | verifier | — | 10.5 |
| 10.7 | Reviewer: confirm zero changes to old flow code paths; confirm Vertex calls go through the proxy not directly. | reviewer | — | 10.6 |
| 10.8 | PR opened on gymgeist `feat/genuiform-onboarding` (do NOT merge — wait for product sign-off). | git-committer | — | 10.7 |

## Files touched (in gymgeist worktree, not in genuiform)

- `/Users/exe008/gymgeist-genuiform/pubspec.yaml`
- `/Users/exe008/gymgeist-genuiform/lib/features/auth/presentation/genui_onboarding_screen.dart`
- `/Users/exe008/gymgeist-genuiform/lib/shared/feature_flags.dart` (or existing)
- `/Users/exe008/gymgeist-genuiform/integration_test/genui_onboarding_flag_test.dart`
- (whatever existing onboarding-routing file the implementer finds during 10.1 survey)

In genuiform itself: only `lib/src/llm/vertex_proxy_client.dart` and the `examples/firebase-proxy/` reference.

## Test strategy

- The only new automated test is the feature-flag integration test in gymgeist.
- Genuiform itself receives bug-fix tests *only* when this phase surfaces real-app issues.
- Manual smoke is the primary signal — this phase exists to validate the library, not to harden it further.

## Parallelism notes

Phase 10 is largely sequential (one app, one flow). Internal parallelism is low. **The only meaningful split is task 10.0 (VertexProxyClient + Firebase Function) running in parallel with the worktree survey 10.1.**

The most important gating signal: do not start Phase 10 until Phase 9 has been signed off and `VertexProxyClient` has a real implementation. Hackathon fragility is exactly the wrong thing to ship to GymGeist users.

