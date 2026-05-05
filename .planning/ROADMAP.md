# genuiform — Roadmap

> Spec source of truth: `/Users/exe008/Downloads/genuiform-spec.md` (v0.4)
> Domain vocabulary: `.planning/DOMAIN.md`
> Phase files: `.planning/phases/PHASE-{N}-{slug}.md`

## Status legend
- `READY`  — no upstream blockers, can start immediately
- `BLOCKED` — waits on listed phases
- `OPTIONAL` — not required for §13.1 hackathon scope; nice-to-have

## Phases

| #  | Title                              | Goal (one-line)                                                                | Status   | Depends on              | Hackathon §13.1 |
|----|------------------------------------|--------------------------------------------------------------------------------|----------|-------------------------|-----------------|
| 0  | Repo hygiene & deps                | pubspec, analysis, build_runner, CI skeleton                                   | READY    | —                       | yes (enabler)   |
| 1  | Models layer                       | All freezed/JSON data classes (Contract, Constraint, Posture, Outcome, …)     | BLOCKED  | 0                       | yes             |
| 2  | Icon registry                      | String-keyed registry of ~150 Material icons used by gymgeist                  | BLOCKED  | 0                       | yes             |
| 3  | LLM client interface + Vertex      | `LlmClient` abstract, `VertexDirectClient`, `FakeLlmClient` test double        | BLOCKED  | 0                       | yes             |
| 4  | Runtime primitives                 | `ConstraintEnforcer`, `OutcomeNavigator`, `EngagementReader`                   | BLOCKED  | 1                       | yes             |
| 5  | Strategies                         | `Strategy` interface, `GenerativeStrategy`, `GuidedStrategy`                   | BLOCKED  | 1, 3, 4                 | yes (Generative); GuidedStrategy can slip to §13.3 |
| 6  | Input widget renderers             | 7 input widgets (slider, choice, multiChoice, text, number, date, info)        | BLOCKED  | 1, 2                    | yes             |
| 7  | GenuiForm widget + FormController  | Public widget, controller, step renderer, streaming indicator                  | BLOCKED  | 5, 6                    | yes             |
| 8  | Examples                           | Freelance qualification (branching) and gymgeist onboarding (ladder+branch)    | BLOCKED  | 7                       | yes             |
| 9  | Integration tests, README, polish  | Gated `integration_test/` against real Vertex; README; pub-readiness checks    | BLOCKED  | 7                       | partial         |
| 10 | GymGeist integration (Stage 2)     | Replace static onboarding flow on a worktree, behind feature flag              | BLOCKED  | 8                       | post-hackathon  |

## Dependency graph

```
        0 (deps + lints + build_runner)
       /|\
      / | \
     1  2  3            ← MODELS, ICONS, LLM-CLIENT can fan out in parallel
     |\  \  \
     | \  \  \
     4  \  \  \         ← RUNTIME needs models
      \  \  \  \
       \  \  \  \
        5 (strategies depend on models + LLM + runtime)
       /
      6 (widgets depend on models + icons; can run in parallel with 4 and 5)
       \
        7 (GenuiForm composes strategies + widgets)
        |
        8 (examples)
        |
        9 (integration tests + readme)
        |
       10 (gymgeist worktree integration)
```

## Parallelism plan

- **After Phase 0 lands**: spin up Phase 1, 2, and 3 simultaneously (3 implementer agents).
- **After Phase 1 lands**: Phase 4 (runtime) and Phase 6 (widgets, also needs 2) can run in parallel.
- **Phase 5** is the join point: needs 1, 3, 4 done. Two implementer agents can build `GuidedStrategy` and `GenerativeStrategy` in parallel.
- **Phase 7** is single-threaded (one widget surface area, tightly coupled).
- **Phase 8** examples can run in parallel (two implementer agents, one per scenario).

## Subagent roles (used in every phase)

- `implementer` — writes production code AND tests (TDD: red test first, then code, then refactor).
- `verifier` — runs the test suite, reproduces acceptance criteria manually, reports back. Never modifies code.
- `reviewer` — reads diff, checks adherence to DOMAIN vocabulary, naming conventions, spec alignment. Suggests edits; does not commit.
- `git-committer` — stages and commits with conventional-commit messages. Only acts after `verifier` and `reviewer` have signed off on a phase.

## Hackathon ordering (§13.1 must-haves)

To hit the May 9 demo, the critical path is:

```
0 → 1 → (3 ‖ 2) → 4 → 5 (Generative only) → 7 → 8 (freelance demo first, gymgeist stub second)
                  ↘ 6 ↗
```

`GuidedStrategy`, `VertexProxyClient`, full session persistence, and the GymGeist worktree integration can all land post-hackathon (§13.3).

