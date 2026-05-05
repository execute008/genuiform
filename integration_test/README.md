# Integration Tests

Tests in this directory make real HTTP requests to the Vertex AI Gemini API and are excluded from the standard `flutter test` run in CI.

## Prerequisites

- `GEMINI_API_KEY` — a valid Gemini API key with access to the target model.
- `GENUIFORM_RUN_INTEGRATION=1` — opt-in gate. Tests check for this variable at runtime and call `markTestSkipped` when it is absent, so the suite remains runnable in CI without secrets leaking.

## Running locally

```bash
export GEMINI_API_KEY=your_key_here
export GENUIFORM_RUN_INTEGRATION=1
flutter test integration_test/
```

## CI policy

Integration tests are never triggered by the standard CI workflow (`ci.yml`). A separate workflow (not yet created) will run them on a protected branch using repository secrets, gated behind a manual approval step.
