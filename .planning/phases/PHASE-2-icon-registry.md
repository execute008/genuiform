# Phase 2 — Icon registry

## Goal

Provide a typed, JSON-serializable registry that maps **string icon names** (which the LLM emits as part of `QuizChoice` and `QuizStepSpec` configurations) to Flutter `IconData`. The registry must contain every Material icon currently used in gymgeist (~150 unique icons grepped from `gymgeist/lib/`) so a generated step that references e.g. `"fitness_center"` resolves cleanly without falling back to a placeholder. Also ship: a fallback icon, a `resolve(String?)` helper, a `registeredIconNames` list (so prompts can be programmatically generated for the LLM), and an `IconRegistryExtension` mechanism so consumers can register additional icons.

## Acceptance criteria

- [ ] `IconRegistry` is a static-only class; not instantiated.
- [ ] `IconRegistry.resolve(String? name)` returns `IconData?` — null if unknown, never throws.
- [ ] `IconRegistry.resolveOrFallback(String? name, {IconData fallback = Icons.help_outline})` returns non-null.
- [ ] `IconRegistry.registeredIconNames` returns a `List<String>` (for prompt injection).
- [ ] `IconRegistry.register(String name, IconData icon)` lets consumers extend the registry; throws `StateError` on duplicate name unless `replaceExisting: true`.
- [ ] All icon names match the Material `Icons.<snake_case>` symbol (e.g. `'fitness_center'` → `Icons.fitness_center`).
- [ ] At minimum the following ~155 names from gymgeist are registered (full list captured in implementation task — see ported list under task 2.1).
- [ ] Tests: every registered name resolves to a non-null `IconData`; round-trip from name → IconData → (look up by codepoint) → name preserves equality.
- [ ] No example or runtime code that hard-codes an `IconData`; everything goes through `IconRegistry.resolve`.

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 2.1 | Write failing test asserting all the icon names from the gymgeist grep resolve to non-null. The list comes from `grep -rh "Icons\." /Users/exe008/gymgeist/lib/ --include="*.dart" \| grep -oE "Icons\.[a-z_0-9]+" \| sort -u`. Spec said ~80; the actual count is ~155 — register them all. | implementer | `test/src/icons/icon_registry_test.dart` | Phase 0 |
| 2.2 | Implement `IconRegistry` with the const map + helpers, making test 2.1 green. | implementer | `lib/src/icons/icon_registry.dart` | 2.1 |
| 2.3 | Add tests for `register()` extension API: register custom, register duplicate (throws), register with `replaceExisting: true` (succeeds). | implementer | `test/src/icons/icon_registry_test.dart` (extend) | 2.2 |
| 2.4 | Implement extension API. | implementer | `lib/src/icons/icon_registry.dart` (extend) | 2.3 |
| 2.5 | Export `IconRegistry` from `lib/genuiform.dart`. | implementer | `lib/genuiform.dart` | 2.4 |
| 2.6 | `flutter analyze && flutter test test/src/icons/`. | verifier | — | 2.5 |
| 2.7 | Reviewer: spot-check that no obvious gymgeist icon was missed by re-running the grep against the registry's keys. | reviewer | — | 2.6 |
| 2.8 | Commit `feat(icons): add IconRegistry with gymgeist Material icon set`. | git-committer | — | 2.7 |

## Files touched

- `/Users/exe008/genuiform/lib/src/icons/icon_registry.dart`
- `/Users/exe008/genuiform/test/src/icons/icon_registry_test.dart`
- `/Users/exe008/genuiform/lib/genuiform.dart` (barrel)

## Test strategy

- Pure unit test — no widget tree needed (`IconData` instances compare cleanly).
- Driver test: build the registered name list once, iterate, assert `resolve` is non-null for each.
- Edge cases: `null` input, unknown name, mixed casing (registry is case-sensitive, document this).
- The gymgeist icon list is **the** test fixture; if a future grep finds a new icon, the test fails until the registry is updated.

## Parallelism notes

Phase 2 is a single chain of small tasks (one file). Parallelism within the phase is low. **However the entire phase runs in parallel with Phase 1 and Phase 3**, since it depends only on Phase 0.

