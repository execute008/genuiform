## 2026-05-18 - Redundant Tree Traversal in Progress Calculation
**Learning:** The `GenuiForm` widget was re-calculating the running contract by walking the outcome tree on every rebuild to compute the progress bar value. Since the `Session` already maintains a pre-computed `runningContract`, this tree-walk was redundant and increased with the complexity of the form.
**Action:** Always prefer pre-computed state properties in the `Session` object over re-calculating them in the UI layer.

## 2026-05-18 - Prompt Building Overhead
**Learning:** Building the system prompt involves sorting and joining a large registry of icon names (~160 items). While seemingly minor, this happens on every turn for every user, creating unnecessary CPU pressure and string allocations.
**Action:** Memoize static components of the system prompt (like icon lists or fixed schemas) to ensure building the dynamic portion is as fast as possible.

## 2026-05-18 - Expensive System Prompt Construction
**Learning:** Building the system prompt for the LLM involves multiple O(N) operations: recursive tree walking for the outcome tree, iterating over all contract fields, and sorting the icon registry. These happen on every turn of every session.
**Action:** Use `Expando<String>` to memoize the string representation of immutable models (Contract, Posture, OutcomeNode). For global mutable state like the IconRegistry, ensure the cache is invalidated when the underlying data changes (e.g., by checking the count of registered icons).
