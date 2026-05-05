## 0.1.0-dev — 2026-05-05

Initial development release. Generative UI Forms for Flutter, powered by Vertex AI Gemini.

### Added

- The four primitives (`Contract`, `Constraints`, `Posture`, `Outcomes`) with the symmetric contract-composition rule for `Layer` / `Branch` / `Outcome` nodes.
- `GenuiForm` widget + `FormController` for drop-in form rendering.
- `GenerativeStrategy` (LLM-driven step generation) and `GuidedStrategy` (LLM-driven catalog routing).
- `VertexDirectClient` for direct Vertex AI Gemini access (dev / server-side only) and `VertexProxyClient` constructor lock-in (full implementation in v0.2 via Firebase Function proxy).
- `FakeLlmClient` exported for consumer test suites.
- `IconRegistry` with 160 Material icons ported from the gymgeist app, extensible via `IconRegistry.register()`.
- Seven input renderers: slider, choice, multiChoice, text, number, date, noneJustInformation.
- Runtime services: `ConstraintEnforcer`, `OutcomeNavigator`, `EngagementReader`.
- Dev tools: `OutcomeTreeView`, `AnswerHistorySidebar`, `SplitUserDemo` (opt-in widgets for demos and debugging).
- Two example scenarios mirroring spec §11: `freelanceQualificationForm` (branching) and `gymgeistOnboardingForm` (ladder + branch).
- 491+ unit + widget tests; FakeLlmClient covers strategy and form-controller flows.
- Gated integration tests under `integration_test/` for end-to-end Vertex AI smoke testing.

### Known limitations (deferred to v0.2)

- `VertexProxyClient` is a constructor stub — full Firebase Function proxy implementation pending.
- `back()` on `FormController` does not regenerate the previous step via the LLM (it restores from history).
- Streaming partial JSON is buffered until the full response is valid (no incremental render).
- The icon registry is shipped in full (~2.2k chars in the system prompt); curating to a subset is a v0.2 optimization.
