# genuiform — example app

A runnable Flutter app demonstrating the two canonical scenarios from the genuiform spec. It is the artifact shown at the Generative UI Global Hackathon (Vienna, May 9 2026).

---

## What this is

**genuiform** is a Flutter library for building forms that adapt to the user as they fill them out, powered by Vertex AI Gemini. Forms are typed functions with a posture and a tree of outcomes — generative inside, predictable outside. This example app wires two real scenario configs (freelance lead qualification and GymGeist onboarding) against a live Vertex AI endpoint so you can walk through both flows interactively.

---

## Run instructions

You need a short-lived Vertex AI OAuth access token and your GCP project ID. The cleanest way to inject them is via `--dart-define` so they never touch source control:

```bash
flutter run -d macos \
  --dart-define=GEMINI_API_KEY=$YOUR_VERTEX_TOKEN \
  --dart-define=GEMINI_PROJECT_ID=$YOUR_GCP_PROJECT
```

Replace `-d macos` with `-d linux`, `-d ios`, or `-d <device-id>` as appropriate. Web is intentionally excluded — `VertexDirectClient` bundles the token client-side and a browser would expose it to anyone with devtools open.

If you omit the `--dart-define` flags, the app shows an "API key" panel on startup. Paste the values there; they live only in the running process.

### Getting a Vertex AI access token

```bash
gcloud auth print-access-token
```

The token is valid for one hour. Re-run the command to refresh it. For longer-lived deployments, see §9 / §13.3 of the spec for `VertexProxyClient` (a Firebase Function that holds the service-account credential server-side).

---

## Demo storyboard (spec §14)

**Setup (10s):** "Static forms ask everyone the same questions. Same depth. Same wording. Watch a generative form do better."

**Demo 1 — Adaptive depth (40s):** GymGeist onboarding ladder.
- Left split: simulated engaged user — long answers, momentum, expressed enthusiasm.
- Right split: simulated tired user — short answers, "idk," hedging.
- Same form config. Same outcome tree. Left user reaches `with_meal_plan` in 14 questions. Right user gracefully exits at `account_only` after 4. Both feel respected. Both convert.

**Demo 2 — Branching outcomes (30s):** Freelance lead qualification.
- Type as a senior CTO with clear brief: form asks 4 questions, picks `book_call`, surfaces calendar.
- Type as a confused early founder: form asks 7 questions, picks `send_proposal`, captures email.
- Type as someone with €500/month budget and €30k/month scope: form asks 3 questions, picks `decline`, politely closes.

**The pitch (20s):** "Four primitives. Contract for what to collect. Constraints for what must never happen. Posture for how it should feel. Outcomes for where it can land. Generative inside, predictable outside. Built for Flutter, powered by Vertex AI. Already shipping in two real apps next week."

---

## Production warning

`VertexDirectClient` bundles the API key (OAuth token) directly in the client. This is fine for demos, hackathon runs, and server-side usage. Do **not** ship it in a mobile app — the token is visible in memory and in network traffic.

For production, use `VertexProxyClient` (spec §9 / §13.3), which calls a Firebase Function that holds the service-account credential on the server. The client sends only a user identity token; the server mints the Vertex credential and proxies the request.

---

## Scenarios

| File | Spec section | Posture | Outcome tree |
|---|---|---|---|
| `lib/scenarios/freelance_qualification.dart` | §11.1 | `salesDiscovery` | Branch → book_call / send_proposal / decline |
| `lib/scenarios/gymgeist_onboarding.dart` | §11.2 | `supportiveOnboarding` | Layer → Layer → Branch (3 options) |

Manual smoke testing (walking through both flows with a real Vertex token) is the user's responsibility. The automated test suite covers only the `ApiKeyPanel` widget.
