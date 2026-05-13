## 2026-05-15 - [HIGH] Constraint Bypass via Choice IDs and Lists
**Vulnerability:** Security/Safety constraints (`StopIf`, `EscalateIf`) could be bypassed if the user selected a choice whose ID did not contain the trigger word, even if the human-readable label did. It also failed to inspect elements of `List` (multi-choice) answers.
**Learning:** The enforcer assumed `answer.answer` would always be a `String` and didn't account for the mapping between internal IDs and user-facing labels in choice-based inputs.
**Prevention:** Always inspect both raw values and human-readable labels for security triggers. Ensure the enforcer handles all possible data types for answers (Strings, Lists, etc.).

## 2026-05-18 - [MEDIUM] Information Leakage in LLM Client Exceptions
**Vulnerability:** `GeminiApiClient` and `VertexProxyClient` included raw HTTP response bodies in thrown exceptions (`AuthError`, `SchemaError`, etc.). These bodies could contain internal API details, project IDs, or stack traces, which might be exposed to the UI or logs.
**Learning:** Developers often include raw response bodies in exceptions for easy debugging, forgetting that these exceptions might propagate to end-user-facing layers.
**Prevention:** Always sanitize exception messages intended for potential propagation. Use `print` or a formal logger to capture raw details for developers before throwing a sanitized exception.
