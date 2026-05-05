# Phase 3 — LLM client interface + Vertex transports + fake

## Goal

Define the `LlmClient` abstraction, ship a working `VertexDirectClient` that talks to Vertex AI Gemini's REST endpoint (with API key + model + `responseSchema` enforcement), and ship a `FakeLlmClient` that scripts responses for unit tests of strategies. `VertexProxyClient` is also stubbed in this phase but its real implementation is deferred to §13.3 — Phase 3 only locks the constructor signature so callers can swap transports without touching strategy code. Streaming is included via a `Stream<String>` of UTF-8 text chunks; non-streaming responses are surfaced as a single-element stream so downstream code is uniform.

## Acceptance criteria

- [ ] `LlmClient` is an abstract class matching the spec §9 signature exactly.
- [ ] `Message` (from Phase 1) is the input message type; system prompt is a separate parameter.
- [ ] `VertexDirectClient`:
  - Configurable `apiKey`, `projectId`, `location`, `model` (string, no enum).
  - Calls `https://{location}-aiplatform.googleapis.com/v1/projects/{projectId}/locations/{location}/publishers/google/models/{model}:streamGenerateContent` with `responseMimeType: application/json` and `responseSchema` set.
  - Buffers streamed chunks until valid JSON (per spec §15 "Streaming partial JSON" — defer fragment-render).
  - Surfaces transport errors as a `LlmClientError` (sealed family with `NetworkError`, `AuthError`, `RateLimitError`, `SchemaError`, `UnknownError`) on the stream.
  - Has dartdoc warning: "**Never ship in a mobile app — for demos and server-side usage.**"
- [ ] `VertexProxyClient`:
  - Constructor accepts `endpoint: String`, `authProvider: Future<String?> Function()`.
  - Throws `UnimplementedError` from `generate` with a message pointing to §13.3, but the type compiles and is exported.
- [ ] `FakeLlmClient`:
  - Accepts a list of scripted `String` responses (one per `generate` invocation).
  - Records each invocation's args (system prompt, messages, schema, model, temperature) into a `List<FakeLlmInvocation>` for test assertions.
  - Optional `responseDelay` to simulate latency.
  - Throws `StateError` if invocations exceed scripted responses.
- [ ] No real Vertex network call ever happens in `flutter test`. The Vertex client tests use `package:http` with a mocked client (`http.Client` injected via constructor for testability).
- [ ] Tests cover: success path, schema-validation success, rate-limit retry-after header parsing (no actual retry yet — just surface the error type), auth failure, malformed JSON.
- [ ] All clients exported from `lib/genuiform.dart`.

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 3.1 | Failing test for `LlmClient` abstract contract: a fake-implementing test class can be instantiated, calling `generate` returns a `Stream<String>`. | implementer | `test/src/llm/llm_client_test.dart` | Phase 1 (`Message`) |
| 3.2 | Implement `LlmClient` abstract class + `LlmClientError` sealed family. | implementer | `lib/src/llm/llm_client.dart` | 3.1 |
| 3.3 | Failing test for `FakeLlmClient`: scripted responses replayed, invocation history recorded, exhausted-script throws. | implementer | `test/src/llm/fake_llm_client_test.dart` | 3.2 |
| 3.4 | Implement `FakeLlmClient`. | implementer | `lib/src/llm/fake_llm_client.dart` | 3.3 |
| 3.5 | Failing test for `VertexDirectClient` happy path using a `MockClient` from `package:http/testing.dart`: assert URL shape, headers, payload, response is decoded into a single-element stream. | implementer | `test/src/llm/vertex_direct_client_test.dart` | 3.2 |
| 3.6 | Implement `VertexDirectClient` (URL builder, payload builder, JSON-line streaming buffer, error mapping). | implementer | `lib/src/llm/vertex_direct_client.dart` | 3.5 |
| 3.7 | Failing tests for error cases (auth, rate-limit, schema, network). | implementer | `test/src/llm/vertex_direct_client_test.dart` (extend) | 3.6 |
| 3.8 | Make error tests pass. | implementer | `lib/src/llm/vertex_direct_client.dart` (extend) | 3.7 |
| 3.9 | Stub `VertexProxyClient` (constructor + `UnimplementedError`-throwing `generate`) + a single test asserting the stub throws with the deferral message. | implementer | `lib/src/llm/vertex_proxy_client.dart`, `test/src/llm/vertex_proxy_client_test.dart` | 3.2 |
| 3.10 | Add `lib/src/llm/schemas.dart` with one helper: `Map<String, dynamic> generativeStrategyResponseSchema()` mirroring spec §10.2. Test asserts required keys + enum values. | implementer | `lib/src/llm/schemas.dart`, `test/src/llm/schemas_test.dart` | Phase 1 (`QuizStepSpec`) |
| 3.11 | Update `lib/genuiform.dart` exports. | implementer | `lib/genuiform.dart` | 3.4, 3.8, 3.9, 3.10 |
| 3.12 | Add `integration_test/vertex_direct_smoke_test.dart` — gated by `String.fromEnvironment('GENUIFORM_RUN_INTEGRATION') == '1'`, hits real Vertex with `gemini-2.5-flash` (the GA-tier default per spec §9.3) and asserts a non-empty JSON response. Skipped by default. | implementer | `integration_test/vertex_direct_smoke_test.dart` | 3.8 |
| 3.13 | `flutter analyze && flutter test test/src/llm/`. | verifier | — | 3.11 |
| 3.14 | Reviewer: confirm no real network call happens in `test/`, only `mocked http.Client`; confirm error sealed family is exhaustive; confirm `responseSchema` parameter name + JSON shape match spec. | reviewer | — | 3.13 |
| 3.15 | Commit `feat(llm): add LlmClient interface, VertexDirectClient, FakeLlmClient, schemas`. | git-committer | — | 3.14 |

## Files touched

- `/Users/exe008/genuiform/lib/src/llm/{llm_client,vertex_direct_client,vertex_proxy_client,fake_llm_client,schemas}.dart`
- `/Users/exe008/genuiform/test/src/llm/*_test.dart`
- `/Users/exe008/genuiform/integration_test/vertex_direct_smoke_test.dart`
- `/Users/exe008/genuiform/lib/genuiform.dart` (barrel)

## Test strategy

- **All Vertex tests use `MockClient` from `package:http/testing.dart`.** Construct `VertexDirectClient(httpClient: MockClient(handler))`.
- The `FakeLlmClient` is a runtime artifact, not a test mock — it's exported from the public API so consumers can also use it for their own tests. Treat it as production code.
- Schema test: encode a sample LLM JSON output, validate against the schema (use `package:json_schema` only if it does not pull in dart:io-incompatible deps; otherwise hand-roll the assertions).
- `integration_test/` is **never run by `flutter test`**. Document this in `integration_test/README.md` (covered in Phase 0).

## Parallelism notes

The dependency sub-graph:

```
3.1 → 3.2 ─┬→ 3.3 → 3.4
           ├→ 3.5 → 3.6 → 3.7 → 3.8 → 3.12
           └→ 3.9
3.10 (independent of 3.2)
```

After 3.2 lands, 3.3/3.4 (fake), 3.5–3.8 (vertex direct), 3.9 (proxy stub) and 3.10 (schemas) can fan out — **4 implementer agents in parallel**.

The whole of Phase 3 runs in parallel with Phase 1 and Phase 2.

