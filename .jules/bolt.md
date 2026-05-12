## 2026-05-18 - Redundant Tree Traversal in Progress Calculation
**Learning:** The `GenuiForm` widget was re-calculating the running contract by walking the outcome tree on every rebuild to compute the progress bar value. Since the `Session` already maintains a pre-computed `runningContract`, this tree-walk was redundant and increased with the complexity of the form.
**Action:** Always prefer pre-computed state properties in the `Session` object over re-calculating them in the UI layer.

## 2026-05-18 - Prompt Building Overhead
**Learning:** Building the system prompt involves sorting and joining a large registry of icon names (~160 items). While seemingly minor, this happens on every turn for every user, creating unnecessary CPU pressure and string allocations.
**Action:** Memoize static components of the system prompt (like icon lists or fixed schemas) to ensure building the dynamic portion is as fast as possible.

## 2026-05-19 - Efficient Model Rendering Cache with Expando
**Learning:** The system prompt builder frequently re-renders string representations of core models (Contract, Posture, OutcomeNode) which are largely immutable during a session. Re-rendering these on every turn is wasteful.
**Action:** Use `Expando<String>` to cache rendered strings keyed by the model instance itself. This avoids memory leaks (using weak keys) while ensuring zero re-rendering overhead for stable configuration objects.
