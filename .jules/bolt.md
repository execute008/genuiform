## 2026-05-18 - Redundant Tree Traversal in Progress Calculation
**Learning:** The `GenuiForm` widget was re-calculating the running contract by walking the outcome tree on every rebuild to compute the progress bar value. Since the `Session` already maintains a pre-computed `runningContract`, this tree-walk was redundant and increased with the complexity of the form.
**Action:** Always prefer pre-computed state properties in the `Session` object over re-calculating them in the UI layer.

## 2026-05-18 - Prompt Building Overhead
**Learning:** Building the system prompt involves sorting and joining a large registry of icon names (~160 items). While seemingly minor, this happens on every turn for every user, creating unnecessary CPU pressure and string allocations.
**Action:** Memoize static components of the system prompt (like icon lists or fixed schemas) to ensure building the dynamic portion is as fast as possible.

## 2026-05-23 - Structural Memoization with Expando
**Learning:** Rendering domain models like `Contract` (bullet lists) or `OutcomeNode` (ASCII trees) into the system prompt is computationally expensive when done every turn. Since these objects are effectively immutable within a session's `FormConfig`, we can use `Expando<String>` to attach their rendered strings directly to the object identity. This provides O(1) retrieval for subsequent turns without requiring the objects to manage their own cache or introducing global state.
**Action:** Use `Expando<String>` in `PromptBuilder` to memoize the string representation of structural domain objects that are part of the static form configuration.
