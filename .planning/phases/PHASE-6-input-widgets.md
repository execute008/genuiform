# Phase 6 — Input widget renderers

## Goal

Port the seven existing input renderers from `gymgeist/lib/shared/presentation/widgets/multi_step_quiz.dart` into `genuiform/lib/src/widgets/inputs/`, one widget per file. Each widget consumes a `QuizStepSpec` (Phase 1) and a value, emits a value via `onChanged`, and resolves any `iconName: String` from the spec through `IconRegistry` (Phase 2). The widgets are pure — they do **not** know about strategies, sessions, or LLMs. Riverpod is **not** a dependency of the library; the gymgeist version uses Riverpod, but for the library version it is dropped (forms are managed by `FormController`, see Phase 7). Visual design is gymgeist-equivalent for v1; restyling can come later.

## Acceptance criteria

- [ ] Seven widgets exist under `lib/src/widgets/inputs/`:
  - `slider_input.dart` (`SliderInput`)
  - `choice_input.dart` (`ChoiceInput`)
  - `multi_choice_input.dart` (`MultiChoiceInput`)
  - `text_input.dart` (`TextInput`)
  - `number_input.dart` (`NumberInput`)
  - `date_input.dart` (`DateInput`)
  - `info_panel.dart` (`InfoPanel`, for `noneJustInformation`)
- [ ] Each widget accepts `(QuizStepSpec spec, dynamic value, ValueChanged<dynamic> onChanged)` and reads its own configuration off `spec.configuration`.
- [ ] `ChoiceInput` and `MultiChoiceInput` resolve icons via `IconRegistry.resolve(choice.iconName)`.
- [ ] No `import 'package:flutter_riverpod/...'` anywhere in the library.
- [ ] Widget tests use `flutter_test`'s `pumpWidget` and assert:
  - widget renders without throwing,
  - tapping / dragging / typing emits the expected value through `onChanged`,
  - icon resolution works for at least one icon per choice-style widget,
  - validation message displays when value is null and `validationMessage` is set (logic moves to a tiny `_ValidationMessage` helper widget).
- [ ] `info_panel.dart` renders `spec.configuration['information']` as the body text, falling back to `spec.description`.
- [ ] All seven widgets exported from `lib/genuiform.dart` so library consumers can compose custom step renderers.

## Tasks

| # | Task | Subagent | Files | Depends on |
|---|------|----------|-------|------------|
| 6.1 | Failing widget test for `SliderInput` (renders, drag updates value, integer mode). Then port. | implementer | `test/src/widgets/inputs/slider_input_test.dart`, `lib/src/widgets/inputs/slider_input.dart` | Phase 1, Phase 2 |
| 6.2 | `ChoiceInput` (radio list, optional text field per choice, icon resolution). Test first. | implementer | `test/src/widgets/inputs/choice_input_test.dart`, `lib/src/widgets/inputs/choice_input.dart` | Phase 1, 2 |
| 6.3 | `MultiChoiceInput`. Test first. | implementer | `test/src/widgets/inputs/multi_choice_input_test.dart`, `lib/src/widgets/inputs/multi_choice_input.dart` | Phase 1, 2 |
| 6.4 | `TextInput` (single + multiline). Test first. | implementer | `test/src/widgets/inputs/text_input_test.dart`, `lib/src/widgets/inputs/text_input.dart` | Phase 1 |
| 6.5 | `NumberInput`. Test first. | implementer | `test/src/widgets/inputs/number_input_test.dart`, `lib/src/widgets/inputs/number_input.dart` | Phase 1 |
| 6.6 | `DateInput`. Test first. | implementer | `test/src/widgets/inputs/date_input_test.dart`, `lib/src/widgets/inputs/date_input.dart` | Phase 1 |
| 6.7 | `InfoPanel` for `noneJustInformation`. Test first. | implementer | `test/src/widgets/inputs/info_panel_test.dart`, `lib/src/widgets/inputs/info_panel.dart` | Phase 1 |
| 6.8 | Add `lib/src/widgets/inputs/inputs.dart` barrel that re-exports all seven. Update `lib/genuiform.dart`. | implementer | `lib/src/widgets/inputs/inputs.dart`, `lib/genuiform.dart` | 6.1–6.7 |
| 6.9 | `flutter analyze && flutter test test/src/widgets/inputs/`. | verifier | — | 6.8 |
| 6.10 | Reviewer: confirm zero Riverpod, zero `Icons.foo` literals (everything via `IconRegistry`), each widget API matches the `(spec, value, onChanged)` shape. | reviewer | — | 6.9 |
| 6.11 | Commit `feat(widgets): port seven input renderers from gymgeist`. | git-committer | — | 6.10 |

## Files touched

- `/Users/exe008/genuiform/lib/src/widgets/inputs/{slider_input,choice_input,multi_choice_input,text_input,number_input,date_input,info_panel,inputs}.dart`
- `/Users/exe008/genuiform/test/src/widgets/inputs/*_test.dart`
- `/Users/exe008/genuiform/lib/genuiform.dart`

## Test strategy

- `pumpWidget` tests in a `MaterialApp` wrapper.
- Use `WidgetTester.tap`, `WidgetTester.enterText`, `WidgetTester.drag` to drive interactions.
- For `DateInput`, tap to open the date picker, then `await tester.pump()` and pick a date programmatically (use `find.text`).
- Golden tests are **not** required for v1 — visual fidelity is "gymgeist-equivalent" but not pixel-locked.

## Parallelism notes

All seven input tasks (6.1 through 6.7) are independent. **Up to seven implementer agents in parallel.** Single join point at 6.8.

Phase 6 depends only on Phase 1 (models) and Phase 2 (icons). It can run **fully in parallel with Phase 4 and Phase 5**.

