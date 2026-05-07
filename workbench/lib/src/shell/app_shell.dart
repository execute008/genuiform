import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import '../editor/code_editor.dart';
import '../preview/form_preview.dart';
import '../scenarios/lead_qualification_dsl.dart';
import 'split_view.dart';

/// The top-level scaffold of the workbench.
///
/// Renders a top app bar with:
/// - The app title ("genuiform workbench")
/// - A scenario [DropdownButton] (visual only in Phase 1)
/// - A "Run" [FilledButton] that resets the form pane
/// - A Reset [IconButton] (same behaviour as Run in Phase 1)
///
/// The body is a [SplitView]: left shows the DSL string for the current
/// scenario; right shows the live [FormPreview].
class AppShell extends StatefulWidget {
  const AppShell({
    required this.client,
    required this.model,
    super.key,
  });

  /// The LLM client wired up from the entry point.
  final LlmClient client;

  /// The Vertex AI model string (e.g. `'gemini-2.5-flash'`).
  final String model;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _selectedScenario = 'Lead qualification';
  static const _scenarios = ['Lead qualification'];

  /// Bumping this key forces [FormPreview] to rebuild and restart the form.
  int _formKey = 0;

  void _runOrReset() {
    setState(() {
      _formKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('genuiform workbench'),
        actions: [
          // ── Scenario picker ───────────────────────────────────────────────
          DropdownButton<String>(
            value: _selectedScenario,
            underline: const SizedBox.shrink(),
            items: _scenarios
                .map(
                  (s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedScenario = value);
            },
          ),
          const SizedBox(width: 12),

          // ── Run button ────────────────────────────────────────────────────
          FilledButton(
            onPressed: _runOrReset,
            child: const Text('Run'),
          ),
          const SizedBox(width: 8),

          // ── Reset button ──────────────────────────────────────────────────
          IconButton(
            tooltip: 'Reset',
            onPressed: _runOrReset,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SplitView(
        left: _LeftPane(dsl: leadQualificationDsl),
        right: FormPreview(
          key: ValueKey(_formKey),
          client: widget.client,
          model: widget.model,
        ),
      ),
    );
  }
}

// ── Left pane ──────────────────────────────────────────────────────────────────

class _LeftPane extends StatelessWidget {
  const _LeftPane({required this.dsl});

  final String dsl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // DSL editor badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              'DSL editor  (read-only — Phase 2)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: CodeEditor(code: dsl, readOnly: true),
          ),
        ],
      ),
    );
  }
}
