# GenUIForm Workbench — Flutter

Workbench for an adaptive form generator. Three live panels:

- **Prompt** — chat with the contract-generation model.
- **Personas** — simulated users that drive split-screen adaptation.
- **Form preview** — Material 3 form rendered live from the contract; reflows per persona engagement.

## Run

```bash
flutter pub get
flutter run            # any device
flutter run -d chrome  # web
flutter run -d macos   # desktop (macOS / windows / linux supported)
```

Requires Flutter 3.22+ / Dart 3.3+.

## Project layout

```
lib/
  main.dart                       app entry
  app/workbench_shell.dart        layout shell (top bar + split panes)
  theme/
    app_theme.dart                ThemeData with M3 dark scheme
    app_colors.dart               token palette
    app_spacing.dart              spacing + radius scale
  models/
    field_spec.dart               input style + range
    scenario.dart                 medical / signup / feedback presets
    persona.dart                  persona library
    chat_message.dart             chat record
  state/
    workbench_controller.dart     ChangeNotifier — single source of truth
  widgets/
    chat_panel.dart               prompt panel
    persona_avatar.dart           CustomPainter avatar
    personas_panel.dart           persona list + generator
    form_preview_panel.dart       device card + status bar
    section_header.dart           section header chrome
```

## Notes

- The contract → DSL pipeline is stubbed in `WorkbenchController.submitPrompt`
  with a 1.4 s delay; replace with a real backend call.
- Color tokens in `app_colors.dart` mirror the Template Design Library v3.
- Persona-driven adaptation lives in `_FormPreviewPanelState._adaptedFields`:
  weak engagement personas drop optional fields; medium engagement caps step count.
