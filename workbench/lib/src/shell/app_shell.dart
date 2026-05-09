import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genuiform/genuiform.dart';

import '../editor/code_editor.dart';
import '../editor/legend_drawer.dart';
import '../llm/a2ui_outcome_emitter.dart';
import '../parser/parse_dsl.dart';
import '../persistence/url_state.dart';
import '../preview/form_preview.dart';
import '../scenarios/scenarios.dart';
import 'split_view.dart';

/// The top-level scaffold of the workbench.
///
/// Renders a top app bar with:
/// - The app title ("genuiform workbench")
/// - A scenario [DropdownButton] populated from [kScenarios]
/// - A "Run" [FilledButton] that re-parses synchronously and resets the form
/// - A Reset [IconButton] (same behaviour as Run)
/// - An "About" icon that opens a modal explaining the DSL constraint
///
/// The body is a [SplitView]: left shows the editable DSL in [_LeftPane];
/// right shows the live [FormPreview].
class AppShell extends StatefulWidget {
  const AppShell({
    required this.client,
    required this.model,
    this.showMockBadge = false,
    super.key,
  });

  /// The LLM client wired up from the entry point.
  final LlmClient client;

  /// The Vertex AI model string (e.g. `'gemini-2.5-flash'`).
  final String model;

  /// When true, a persistent MOCK badge is shown in the top bar.
  /// Set when `--dart-define=USE_MOCK=true`.
  final bool showMockBadge;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// The id of the currently selected scenario, or `'lead_qualification'`
  /// when no URL hash is present or the hash doesn't match any scenario.
  String _currentScenarioId = 'lead_qualification';

  /// The current DSL source being displayed and edited in the left pane.
  late String _dsl;

  /// Latest parse result. Guaranteed non-null after initState.
  late ParseResult _parseResult;

  /// Bumping this key forces [FormPreview] to rebuild and restart the form.
  int _formKey = 0;

  /// Debounce timer for re-parsing after keystrokes.
  Timer? _debounce;

  /// Last DSL value that was synced to the URL hash (avoids redundant writes).
  String _lastSyncedDsl = '';

  /// Used to open the [LegendDrawer] from the AppBar action button — the
  /// AppBar's BuildContext doesn't see the [Scaffold] above it, so we route
  /// through a key instead of [Scaffold.of].
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Emitter constructed once per session, shared across form completions.
  ///
  /// Always constructed (even when the client is a mock), because the gating
  /// decision — whether to actually call through to the emitter — lives in
  /// [FormPreview], which has visibility into both the client type and the
  /// compile-time [_kUseA2uiHandoff] flag.
  late final A2uiOutcomeEmitter _a2uiEmitter;

  @override
  void initState() {
    super.initState();

    // Attempt to restore state from the URL hash first.
    final hashDsl = readDslFromUrlHash();
    if (hashDsl != null) {
      _dsl = hashDsl;
      // Find matching scenario by exact DSL equality; fall back to default.
      final match = kScenarios.where((s) => s.dsl == hashDsl).firstOrNull;
      _currentScenarioId = match?.id ?? 'lead_qualification';
    } else {
      _dsl = kScenarios.first.dsl;
      _currentScenarioId = kScenarios.first.id;
    }

    // Parse eagerly so _parseResult is always non-null before the first build.
    _parseResult = parseDsl(_dsl);

    // Sync the clean initial state to the URL.
    if (_parseResult.isClean) {
      _syncUrl();
    }

    // Construct the A2UI emitter once per session.
    // AppShell constructs always; FormPreview gates on client type + flag.
    _a2uiEmitter = A2uiOutcomeEmitter(
      client: widget.client,
      model: widget.model,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Writes the current DSL to the URL hash when it is clean and has changed.
  void _syncUrl() {
    if (_parseResult.isClean && _dsl != _lastSyncedDsl) {
      syncHashToUrl(_dsl);
      _lastSyncedDsl = _dsl;
    }
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
      _syncUrl();
    });
  }

  /// Called when the user picks a new scenario from the dropdown.
  void _onScenarioPicked(Scenario scenario) {
    _debounce?.cancel();
    setState(() {
      _currentScenarioId = scenario.id;
      _dsl = scenario.dsl;
      _parseResult = parseDsl(_dsl);
      // Always bump the form key on a deliberate scenario switch — cursor
      // reset and form restart are desired behaviour here.
      _formKey++;
    });
    _syncUrl();
  }

  /// Re-parses the current DSL synchronously and bumps the form key
  /// unconditionally, aborting any in-flight stream.
  void _runOrReset() {
    _debounce?.cancel();
    setState(() {
      _parseResult = parseDsl(_dsl);
      _formKey++;
    });
    _syncUrl();
  }

  @override
  Widget build(BuildContext context) {
    // Only pass the form when parsing produced a complete result.
    final hasForm = _parseResult.hasForm;

    final currentScenario =
        kScenarios.firstWhere((s) => s.id == _currentScenarioId);

    // The dropdown is anchored to the last-picked scenario, but the editor
    // content may have drifted. Render a "(modified)" suffix on the closed
    // dropdown when the DSL no longer matches any preset exactly.
    final isModified = !kScenarios.any((s) => s.dsl == _dsl);

    // Build a side-table of outcomeId → SimulatedHandoff from the parsed DSL.
    final handoffMap = _parseResult.handoffMap ?? const {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;

        // Build the two panes once, then hand them to either layout.
        final leftPane = _LeftPane(
          dsl: _dsl,
          parseResult: _parseResult,
          onChanged: _onDslChanged,
        );

        final Widget rightPane = hasForm
            ? FormPreview(
                key: ValueKey(_formKey),
                contract: _parseResult.contract!,
                constraints: _parseResult.constraints!,
                posture: _parseResult.posture!,
                outcomes: _parseResult.outcomes!,
                client: widget.client,
                model: widget.model,
                handoffMap: handoffMap,
                onRestartRequested: _runOrReset,
                emitter: _a2uiEmitter,
              )
            : const _NoParsedFormPlaceholder();

        final Widget shellBody = isMobile
            ? _MobileLayout(left: leftPane, right: rightPane)
            : SplitView(left: leftPane, right: rightPane);

        return Scaffold(
          key: _scaffoldKey,
          endDrawer: const LegendDrawer(),
          appBar: AppBar(
            title: const Text('genuiform workbench'),
            actions: [
              // ── Mock badge ────────────────────────────────────────────────
              if (widget.showMockBadge) ...[
                Chip(
                  label: const Text('MOCK'),
                  backgroundColor: Colors.amber.shade700,
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],

              // ── Scenario picker ───────────────────────────────────────────
              DropdownButton<Scenario>(
                value: currentScenario,
                underline: const SizedBox.shrink(),
                selectedItemBuilder: (context) => kScenarios
                    .map(
                      (s) => Center(
                        child: Text(
                          isModified && s.id == currentScenario.id
                              ? '${s.name} (modified)'
                              : s.name,
                        ),
                      ),
                    )
                    .toList(),
                items: kScenarios
                    .map(
                      (s) => DropdownMenuItem<Scenario>(
                        value: s,
                        child: Text(s.name),
                      ),
                    )
                    .toList(),
                onChanged: (scenario) {
                  if (scenario == null) return;
                  _onScenarioPicked(scenario);
                },
              ),
              const SizedBox(width: 12),

              // ── Run button ────────────────────────────────────────────────
              Tooltip(
                message: '⌘ Enter / Ctrl Enter',
                child: FilledButton(
                  onPressed: _runOrReset,
                  child: const Text('Run'),
                ),
              ),
              const SizedBox(width: 8),

              // ── Reset button ──────────────────────────────────────────────
              IconButton(
                tooltip: 'Reset',
                onPressed: _runOrReset,
                icon: const Icon(Icons.refresh),
              ),

              // ── DSL reference drawer ──────────────────────────────────────
              IconButton(
                tooltip: 'DSL reference',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.menu_book_outlined),
              ),

              // ── About button ──────────────────────────────────────────────
              IconButton(
                tooltip: 'About this workbench',
                onPressed: () => _showAboutDialog(context),
                icon: const Icon(Icons.info_outline),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              // Cmd+Enter on macOS, Ctrl+Enter elsewhere.
              const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                  _runOrReset,
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  _runOrReset,
            },
            child: Focus(
              autofocus: true,
              child: isMobile
                  ? Column(
                      children: [
                        _MobileBanner(onDismiss: () => setState(() {})),
                        Expanded(child: shellBody),
                      ],
                    )
                  : shellBody,
            ),
          ),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const _AboutDialog(),
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

// ── About dialog ───────────────────────────────────────────────────────────────

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About the workbench'),
      content: const SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DSL editor, not a Dart compiler',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This editor is a DSL parser, not a Dart compiler. Flutter Web '
                'cannot compile Dart at runtime, so we accept a constrained '
                'Dart-shaped DSL and parse it into real genuiform types. '
                'Anything outside the grammar is a parse error displayed inline.',
              ),
              SizedBox(height: 16),
              Text(
                'What this means for you',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'The DSL is a strict subset of Dart. No conditionals, no helpers, '
                'no imports — just literal config trees. Posture presets '
                '(salesDiscovery, supportiveOnboarding, clinicalIntake), '
                'constraints, and outcome trees are all supported. Custom '
                'callback functions are replaced by named registry entries '
                '(e.g. Handoff(onReached: bookCalendly)).',
              ),
              SizedBox(height: 16),
              Text(
                'What this gets you',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Pure Flutter Web — no backend, no compilation pipeline, zero '
                'stage risk. Edits re-parse within 250ms and rebuild the live '
                'form on the right. Looks identical to real Dart to a judge '
                'watching over your shoulder.',
              ),
              SizedBox(height: 16),
              Text(
                'Where this sits next to A2UI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "Google's A2UI protocol (a2ui.org) and the flutter/genui SDK "
                'let an agent draw a UI per turn. genuiform is a layer above '
                "that: where A2UI asks \"what should the UI look like this "
                'turn?", genuiform asks "what should we ask next, given hard '
                'invariants on what may ever be collected and where the form '
                'may land?". The workbench closes the live round-trip: Vertex '
                'emits A2UI v0.9 JSON per outcome, flutter/genui renders the '
                'Surface, and the in-Surface Restart button fires back through '
                'an A2UI action — all while the form-collection loop stays '
                "inside genuiform's typed primitives.",
              ),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              Text(
                'genuiform workbench — Spec v0.1, May 2026\n'
                'See README.md for the full library documentation.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ── Mobile layout (stacked, 6.6) ──────────────────────────────────────────────

class _MobileLayout extends StatefulWidget {
  const _MobileLayout({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  bool _editorCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Editor pane (collapsible)
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: SizedBox(
            height: _editorCollapsed ? 0 : 300,
            child: widget.left,
          ),
        ),
        // Collapse/expand tab
        GestureDetector(
          onTap: () => setState(() => _editorCollapsed = !_editorCollapsed),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _editorCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _editorCollapsed ? 'Show editor' : 'Hide editor',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        // Form pane
        Expanded(child: widget.right),
      ],
    );
  }
}

// ── Mobile banner (6.6) ───────────────────────────────────────────────────────

class _MobileBanner extends StatefulWidget {
  const _MobileBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_MobileBanner> createState() => _MobileBannerState();
}

class _MobileBannerState extends State<_MobileBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return MaterialBanner(
      content: const Text('Best viewed on desktop'),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _dismissed = true);
            widget.onDismiss();
          },
          child: const Text('Got it'),
        ),
      ],
    );
  }
}
