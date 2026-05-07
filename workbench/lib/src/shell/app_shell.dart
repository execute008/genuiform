import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import '../editor/code_editor.dart';
import '../parser/parse_dsl.dart';
import '../preview/form_preview.dart';
import '../scenarios/lead_qualification_dsl.dart';
import 'split_view.dart';

/// The top-level scaffold of the workbench.
///
/// Renders a top app bar with:
/// - The app title ("genuiform workbench")
/// - A scenario [DropdownButton] (visual only in Phase 1–4)
/// - A "Run" [FilledButton] that re-parses synchronously and resets the form
/// - A Reset [IconButton] (same behaviour as Run)
///
/// The body is a [SplitView]: left shows the editable DSL in [_LeftPane];
/// right shows the live [FormPreview].
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

  /// The current DSL source being displayed and edited in the left pane.
  String _dsl = leadQualificationDsl;

  /// Latest parse result. Guaranteed non-null after initState.
  late ParseResult _parseResult;

  /// Bumping this key forces [FormPreview] to rebuild and restart the form.
  int _formKey = 0;

  /// Debounce timer for re-parsing after keystrokes.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Parse eagerly so _parseResult is always non-null before the first build.
    _parseResult = parseDsl(_dsl);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onDslChanged(String newDsl) {
    _dsl = newDsl;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final result = parseDsl(_dsl);
      setState(() {
        _parseResult = result;
        // Only bump the form key on a clean parse so a transient error does
        // not kill an in-progress LLM stream.
        if (result.isClean) {
          _formKey++;
        }
      });
    });
  }

  /// Re-parses the current DSL synchronously and bumps the form key
  /// unconditionally, aborting any in-flight stream.
  void _runOrReset() {
    _debounce?.cancel();
    setState(() {
      _parseResult = parseDsl(_dsl);
      _formKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only pass the form when parsing produced a complete result.
    final hasForm = _parseResult.hasForm;

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
        left: _LeftPane(
          dsl: _dsl,
          parseResult: _parseResult,
          onChanged: _onDslChanged,
        ),
        right: hasForm
            ? FormPreview(
                key: ValueKey(_formKey),
                contract: _parseResult.contract!,
                constraints: _parseResult.constraints!,
                posture: _parseResult.posture!,
                outcomes: _parseResult.outcomes!,
                client: widget.client,
                model: widget.model,
              )
            : const _NoParsedFormPlaceholder(),
      ),
    );
  }
}

// ── Left pane ──────────────────────────────────────────────────────────────────

class _LeftPane extends StatelessWidget {
  const _LeftPane({
    required this.dsl,
    required this.parseResult,
    required this.onChanged,
  });

  final String dsl;
  final ParseResult parseResult;
  final ValueChanged<String> onChanged;

  /// Build the list of [EditorErrorMark]s from [parseResult.errors].
  List<EditorErrorMark> get _errorMarks => parseResult.errors
      .map(
        (e) => EditorErrorMark(
          line: e.line,
          column: e.column,
          message: e.message,
          hint: e.hint,
        ),
      )
      .toList();

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
              'DSL editor',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: CodeEditor(
              code: dsl,
              readOnly: false,
              onChanged: onChanged,
              errors: _errorMarks,
            ),
          ),
          // Parse status footer (§4.3)
          _ParseStatusFooter(parseResult: parseResult),
        ],
      ),
    );
  }
}

// ── Parse status footer ────────────────────────────────────────────────────────

/// A compact footer below the editor showing parse status.
///
/// - green ✓ "parsed cleanly" when [parseResult.isClean]
/// - amber ⚠ "warnings: N" when errors present but form still renders
/// - red ✕ "N error(s)" when fatal — form not rebuilt
///
/// The first error's line/col is appended in muted small text.
class _ParseStatusFooter extends StatelessWidget {
  const _ParseStatusFooter({required this.parseResult});

  final ParseResult parseResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    late final Color iconColor;
    late final IconData icon;
    late final String label;

    if (parseResult.isClean) {
      iconColor = Colors.green;
      icon = Icons.check_circle_outline;
      label = 'parsed cleanly';
    } else if (parseResult.hasErrors && parseResult.hasForm) {
      // Soft errors — form still renders with warnings.
      iconColor = Colors.amber;
      icon = Icons.warning_amber_outlined;
      final n = parseResult.errors.length;
      label = 'warnings: $n';
    } else {
      // Fatal — form not rebuilt.
      iconColor = Colors.red;
      icon = Icons.cancel_outlined;
      final n = parseResult.errors.length;
      label = '$n error${n == 1 ? '' : 's'}';
    }

    final firstError =
        parseResult.hasErrors ? parseResult.errors.first : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(color: iconColor),
          ),
          if (firstError != null) ...[
            const SizedBox(width: 8),
            Text(
              'Line ${firstError.line}, col ${firstError.column}',
              style: textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Right pane placeholder ─────────────────────────────────────────────────────

class _NoParsedFormPlaceholder extends StatelessWidget {
  const _NoParsedFormPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Fix parse errors to preview the form.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
