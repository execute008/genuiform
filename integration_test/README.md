# Integration Tests

Tests in this directory make real HTTP requests to the Gemini API and are excluded from the standard `flutter test` run in CI.

## Prerequisites

- `GEMINI_API_KEY` — a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey).
- `GENUIFORM_RUN_INTEGRATION=1` — opt-in gate. Tests check for this variable at runtime and call `markTestSkipped` when it is absent, so the suite remains runnable in CI without secrets leaking.

## Running locally

```bash
flutter test integration_test/ \
  --dart-define=GENUIFORM_RUN_INTEGRATION=1 \
  --dart-define=GEMINI_API_KEY=your_key_here
```

Or with environment variables:

```bash
export GEMINI_API_KEY=your_key_here
export GENUIFORM_RUN_INTEGRATION=1
flutter test integration_test/
```

## Test suite

| File | Scenario | Max steps |
|---|---|---|
| `freelance_qualification_e2e_test.dart` | Terse user drives freelance form to a terminal Outcome | 8 |
| `gymgeist_onboarding_e2e_test.dart` | (a) short-answer user exits at `account_only` layer ≤4 steps | 4 |
| `gymgeist_onboarding_e2e_test.dart` | (b) engaged user reaches `with_meal_plan` Outcome ≤14 steps | 14 |

## Cost note

Each integration test run costs approximately **€0.005** (gemini-2.5-flash, ~6–14 LLM steps per scenario at ~€0.0004 per step). The full suite (~20 steps total) costs well under €0.01 per run. **Don't run in CI** — use a manual trigger with repository secrets.

## CI policy

Integration tests are never triggered by the standard CI workflow (`ci.yml`). A separate workflow (not yet created) will run them on a protected branch using repository secrets, gated behind a manual approval step.
