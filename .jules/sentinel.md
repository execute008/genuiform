## 2026-05-15 - [HIGH] Constraint Bypass via Choice IDs and Lists
**Vulnerability:** Security/Safety constraints (`StopIf`, `EscalateIf`) could be bypassed if the user selected a choice whose ID did not contain the trigger word, even if the human-readable label did. It also failed to inspect elements of `List` (multi-choice) answers.
**Learning:** The enforcer assumed `answer.answer` would always be a `String` and didn't account for the mapping between internal IDs and user-facing labels in choice-based inputs.
**Prevention:** Always inspect both raw values and human-readable labels for security triggers. Ensure the enforcer handles all possible data types for answers (Strings, Lists, etc.).
