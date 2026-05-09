# genuiform — example app

A runnable Flutter app demonstrating the two canonical scenarios from the genuiform spec. It is the artifact shown at the Generative UI Global Hackathon (Vienna, May 9 2026).

---

## What this is

**genuiform** is a Flutter library for building forms that adapt to the user as they fill them out, powered by Gemini. Forms are typed functions with a posture and a tree of outcomes — generative inside, predictable outside. This example app wires two real scenario configs (freelance lead qualification and GymGeist onboarding) against a live Gemini endpoint so you can walk through both flows interactively.

---

## Run instructions

You need a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey) (free tier works). The cleanest way to inject it is via `--dart-define` so it never touches source control:

```bash
flutter run -d macos \
  --dart-define=GEMINI_API_KEY=$YOUR_GEMINI_KEY
```

Replace `-d macos` with `-d linux`, `-d ios`, or `-d <device-id>` as appropriate. Web is intentionally excluded — `GeminiApiClient` bundles the key client-side and a browser would expose it to anyone with devtools open.

If you omit the `--dart-define` flag, the app shows an "API key" panel on startup. Paste the value there; it lives only in the running process.

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

**The pitch (20s):** "Four primitives. Contract for what to collect. Constraints for what must never happen. Posture for how it should feel. Outcomes for where it can land. Generative inside, predictable outside. Built for Flutter, powered by Gemini. Already shipping in two real apps next week."

---

## Production warning

`GeminiApiClient` bundles the API key directly in the client. This is fine for demos, hackathon runs, and server-side usage. For shipped Flutter apps you should either:

- proxy through your own backend (`VertexProxyClient` — spec §9 / §13.3, a Firebase Function holds the service-account credential on the server and the client sends only a user identity token), or
- use Firebase Vertex AI (`FirebaseVertexAI.instance` from `package:firebase_vertex_ai`) when the Flutter project is already on Firebase.

Vertex AI from a Flutter client must never be wired with a baked-in bearer token + project ID — it has no static client-side API-key model.

---

## Scenarios

| File | Spec section | Posture | Outcome tree |
|---|---|---|---|
| `lib/scenarios/freelance_qualification.dart` | §11.1 | `salesDiscovery` | Branch → book_call / send_proposal / decline |
| `lib/scenarios/gymgeist_onboarding.dart` | §11.2 | `supportiveOnboarding` | Layer → Layer → Branch (3 options) |

Manual smoke testing (walking through both flows with a real Gemini key) is the user's responsibility. The automated test suite covers only the `ApiKeyPanel` widget.
