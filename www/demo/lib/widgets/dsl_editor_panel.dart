import 'package:flutter/material.dart';
import 'package:genuiform_a2ui/genuiform_a2ui.dart';

import '../state/workbench_controller.dart';
import '../src/editor/code_editor.dart';
import '../src/editor/legend_drawer.dart';
import '../src/scenarios/scenarios.dart';
import '../src/preview/form_preview.dart';
import '../src/shell/split_view.dart';
import '../src/parser/parse_dsl.dart';

/// DSL Editor panel with split view: code editor on left, form preview on right
class DslEditorPanel extends StatefulWidget {
  final WorkbenchController controller;

  const DslEditorPanel({required this.controller, super.key});

  @override
  State<DslEditorPanel> createState() => _DslEditorPanelState();
}

class _DslEditorPanelState extends State<DslEditorPanel> {
  bool _legendOpen = false;
  
  /// Build the list of [EditorErrorMark]s from [parseResult.errors].
  List<EditorErrorMark> get _errorMarks => widget.controller.parseResult.errors
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
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final hasForm = widget.controller.committedParseResult.hasForm;
        
        // Build the toolbar
        final toolbar = _DslEditorToolbar(
          controller: widget.controller,
          legendOpen: _legendOpen,
          onToggleLegend: () => setState(() => _legendOpen = !_legendOpen),
        );
        
        // Build the left pane (editor)
        final leftPane = _LeftPane(
          controller: widget.controller,
          legendOpen: _legendOpen,
          onToggleLegend: () => setState(() => _legendOpen = !_legendOpen),
          errorMarks: _errorMarks,
        );

        // Build the right pane (form preview)
        final Widget rightPane = hasForm
            ? FormPreview(
                key: ValueKey(widget.controller.formKey),
                contract: widget.controller.committedParseResult.contract!,
                constraints: widget.controller.committedParseResult.constraints!,
                posture: widget.controller.committedParseResult.posture!,
                outcomes: widget.controller.committedParseResult.outcomes!,
                client: widget.controller.buildClient(),
                model: widget.controller.model.value,
                handoffMap: widget.controller.committedParseResult.handoffMap ?? const {},
                onRestartRequested: widget.controller.runOrReset,
                emitter: A2uiOutcomeEmitter(
                  source: GeminiA2uiOutcomeSource(
                    client: widget.controller.buildClient(),
                    model: widget.controller.model.value.endsWith('-latest')
                        ? 'gemini-2.5-flash'
                        : widget.controller.model.value,
                  ),
                ),
                onControllerCreated: (c) => {},
              )
            : const _NoParsedFormPlaceholder();

        return Column(
          children: [
            toolbar,
            Expanded(
              child: SplitView(
                left: leftPane,
                right: rightPane,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DslEditorToolbar extends StatelessWidget {
  final WorkbenchController controller;
  final bool legendOpen;
  final VoidCallback onToggleLegend;

  const _DslEditorToolbar({
    required this.controller,
    required this.legendOpen,
    required this.onToggleLegend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          // Scenario picker
          Text('Scenario:', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: controller.currentScenarioId,
            underline: const SizedBox.shrink(),
            items: kScenarios.map((s) => DropdownMenuItem<String>(
              value: s.id,
              child: Text(s.name),
            )).toList(),
            onChanged: (scenarioId) {
              if (scenarioId != null) {
                controller.onScenarioPicked(scenarioId);
              }
            },
          ),
          const SizedBox(width: 16),
          
          // Model picker
          Text('Model:', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          ValueListenableBuilder<String>(
            valueListenable: controller.model,
            builder: (context, current, _) {
              return DropdownButton<String>(
                value: current,
                underline: const SizedBox.shrink(),
                items: WorkbenchController.candidateModels.map((m) => DropdownMenuItem<String>(
                  value: m,
                  child: Text(m),
                )).toList(),
                onChanged: (next) {
                  if (next != null && next != current) {
                    controller.model.value = next;
                  }
                },
              );
            },
          ),
          
          const Spacer(),
          
          // Legend toggle
          IconButton(
            tooltip: legendOpen ? 'Hide DSL reference' : 'DSL reference',
            onPressed: onToggleLegend,
            isSelected: legendOpen,
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            selectedIcon: const Icon(Icons.menu_book, size: 18),
          ),
          const SizedBox(width: 8),
          
          // Run button
          FilledButton(
            onPressed: controller.runOrReset,
            child: const Text('Run'),
          ),
          const SizedBox(width: 8),
          
          // Reset button
          IconButton(
            tooltip: 'Reset',
            onPressed: controller.runOrReset,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _LeftPane extends StatelessWidget {
  final WorkbenchController controller;
  final bool legendOpen;
  final VoidCallback onToggleLegend;
  final List<EditorErrorMark> errorMarks;

  const _LeftPane({
    required this.controller,
    required this.legendOpen,
    required this.onToggleLegend,
    required this.errorMarks,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final editorColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // DSL editor badge
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          color: cs.surfaceContainerHighest,
          child: Text(
            'DSL Editor',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: CodeEditor(
            code: controller.dsl,
            readOnly: false,
            onChanged: controller.onDslChanged,
            errors: errorMarks,
          ),
        ),
        // Parse status footer
        _ParseStatusFooter(parseResult: controller.parseResult),
      ],
    );

    return Container(
      color: cs.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: editorColumn),
          if (legendOpen) LegendDrawer(onClose: onToggleLegend),
        ],
      ),
    );
  }
}

/// Parse status footer showing parse results
class _ParseStatusFooter extends StatelessWidget {
  const _ParseStatusFooter({required this.parseResult});

  final ParseResult parseResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    late final Color iconColor;
    late final IconData icon;
    late final String label;

    if (parseResult.isClean) {
      iconColor = Colors.green;
      icon = Icons.check_circle_outline;
      label = 'parsed cleanly';
    } else if (parseResult.hasErrors && parseResult.hasForm) {
      iconColor = Colors.amber;
      icon = Icons.warning_amber_outlined;
      final n = parseResult.errors.length;
      label = 'warnings: $n';
    } else {
      iconColor = Colors.red;
      icon = Icons.cancel_outlined;
      final n = parseResult.errors.length;
      label = '$n error${n == 1 ? '' : 's'}';
    }

    final firstError = parseResult.hasErrors ? parseResult.errors.first : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: iconColor),
          ),
          if (firstError != null) ...[
            const SizedBox(width: 8),
            Text(
              'Line ${firstError.line}, col ${firstError.column}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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