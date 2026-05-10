import 'package:flutter/material.dart';

import 'package:genuiform_a2ui/genuiform_a2ui.dart';

import '../state/workbench_controller.dart';
import '../theme/app_spacing.dart';
import '../widgets/api_key_dialog.dart';
import '../src/editor/code_editor.dart';
import '../src/editor/legend_drawer.dart';
import '../src/parser/parse_dsl.dart';
import '../src/editor/progress_drawer.dart';
import '../src/preview/form_preview.dart';
import '../src/scenarios/scenarios.dart';
import '../widgets/agent_chat_panel.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WorkbenchShell extends StatefulWidget {
  const WorkbenchShell({super.key});

  @override
  State<WorkbenchShell> createState() => _WorkbenchShellState();
}

class _WorkbenchShellState extends State<WorkbenchShell> {
  final WorkbenchController _controller = WorkbenchController();
  bool _legendOpen = false;
  bool _showChat = false;

  @override
  void initState() {
    super.initState();
    _controller.init().then((_) {
      if (!mounted) return;
      // Force rebuild so API key button reflects the loaded key state, then
      // show the dialog only if no key was found in storage.
      setState(() {});
      if (!_controller.geminiService.hasApiKey) {
        _showApiKeyDialog();
      }
    });
  }

  Future<void> _showApiKeyDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApiKeyDialog(
        initialKey: _controller.geminiService.apiKey,
      ),
    );
    if (result != null) {
      await _controller.geminiService.setApiKey(result);
      _controller.refresh();
    }
  }

  void _toggleLegend() {
    setState(() {
      _legendOpen = !_legendOpen;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRightPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasForm = _controller.committedParseResult.hasForm;

    if (!hasForm) {
      return Container(
        color: cs.surface,
        child: Center(
          child: Text(
            'Fix parse errors to preview the form',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      color: cs.surface,
      child: FormPreview(
        key: ValueKey(_controller.formKey),
        contract: _controller.committedParseResult.contract!,
        constraints: _controller.committedParseResult.constraints!,
        posture: _controller.committedParseResult.posture!,
        outcomes: _controller.committedParseResult.outcomes!,
        client: _controller.buildClient(),
        model: _controller.model.value,
        temperature: _controller.temperature.value,
        handoffMap: _controller.committedParseResult.handoffMap ?? const {},
        onRestartRequested: _controller.runOrReset,
        emitter: A2uiOutcomeEmitter(
          source: GeminiA2uiOutcomeSource(
            client: _controller.buildClient(),
            model: _controller.model.value.endsWith('-latest')
                ? 'gemini-2.5-flash'
                : _controller.model.value,
          ),
        ),
        onControllerCreated: (c) => _controller.controllerRef.value = c,
        scenarioId: _controller.mascotEnabled.value
            ? _controller.currentScenarioId
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Column(
              children: [
                _TopBar(controller: _controller),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 860;
                      if (!wide) {
                        return ListView(
                          children: [
                            SizedBox(
                              height: 480,
                              child: _EditorPanel(
                                controller: _controller,
                                legendOpen: _legendOpen,
                                onToggleLegend: _toggleLegend,
                                showChat: _showChat,
                                onToggleChat: () =>
                                    setState(() => _showChat = !_showChat),
                              ),
                            ),
                            Divider(color: cs.outlineVariant, height: 1),
                            SizedBox(
                              height: 720,
                              child: _buildRightPanel(context),
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left column: editor/chat panel
                          SizedBox(
                            width: constraints.maxWidth * 0.38,
                            child: _EditorPanel(
                              controller: _controller,
                              legendOpen: _legendOpen,
                              onToggleLegend: _toggleLegend,
                              showChat: _showChat,
                              onToggleChat: () =>
                                  setState(() => _showChat = !_showChat),
                            ),
                          ),
                          VerticalDivider(
                            color: cs.outlineVariant,
                            width: 1,
                          ),
                          // Right column: form preview
                          Expanded(
                            child: _buildRightPanel(context),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final WorkbenchController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icon.svg',
            width: 28,
            height: 28,
          ),
          const SizedBox(width: AppSpacing.s3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'genUIform',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.s5),
          Container(
            height: 20,
            width: 1,
            color: cs.outlineVariant,
          ),
          const SizedBox(width: AppSpacing.s4),

          const Spacer(),
          _MascotToggle(controller: controller),
          const SizedBox(width: AppSpacing.s3),
          _TemperatureSlider(notifier: controller.temperature),
          const SizedBox(width: AppSpacing.s3),
          IconButton(
            tooltip: 'Contract progress',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                clipBehavior: Clip.antiAlias,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: ProgressDrawer(
                    controllerRef: controller.controllerRef,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.timeline_outlined, size: 18),
          ),
          const SizedBox(width: AppSpacing.s2),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('Run'),
            onPressed: controller.runOrReset,
          ),
          const SizedBox(width: AppSpacing.s2),
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final hasKey = controller.geminiService.hasApiKey;
              return FilledButton.tonalIcon(
                icon: Icon(
                  hasKey ? Icons.check_circle : Icons.key,
                  size: 16,
                  color: hasKey ? const Color(0xFF9FD4A3) : null,
                ),
                label: Text(hasKey ? 'API Key Set' : 'Add API Key'),
                onPressed: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (_) => ApiKeyDialog(
                      initialKey: controller.geminiService.apiKey,
                    ),
                  );
                  if (result != null) {
                    await controller.geminiService.setApiKey(result);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Editor / Chat panel ───────────────────────────────────────────────────────

class _EditorPanel extends StatelessWidget {
  final WorkbenchController controller;
  final bool legendOpen;
  final VoidCallback onToggleLegend;
  final bool showChat;
  final VoidCallback onToggleChat;

  const _EditorPanel({
    required this.controller,
    required this.legendOpen,
    required this.onToggleLegend,
    required this.showChat,
    required this.onToggleChat,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        return Column(
          children: [
            // Header: Code/Chat toggle + model selector
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Code'),
                        icon: Icon(Icons.code, size: 14),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Chat'),
                        icon: Icon(Icons.smart_toy_outlined, size: 14),
                      ),
                    ],
                    selected: {showChat},
                    onSelectionChanged: (_) => onToggleChat(),
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  ValueListenableBuilder<String>(
                    valueListenable: c.model,
                    builder: (context, current, _) {
                      return DropdownButton<String>(
                        value: current,
                        underline: const SizedBox.shrink(),
                        style: TextStyle(fontSize: 13, color: cs.onSurface),
                        items: WorkbenchController.candidateModels
                            .map((m) => DropdownMenuItem<String>(
                                  value: m,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(m),
                                  ),
                                ))
                            .toList(),
                        onChanged: (next) {
                          if (next != null && next != current) {
                            c.model.value = next;
                          }
                        },
                      );
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // Body: code editor or agent chat
            Expanded(
              child: showChat
                  ? AgentChatPanel(controller: c)
                  : _buildCodeEditor(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCodeEditor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scenario selector bar
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Text('Scenario:',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(width: AppSpacing.s2),
              DropdownButton<String>(
                value: c.currentScenarioId,
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                items: kScenarios
                    .map((s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(s.name),
                        ))
                    .toList(),
                onChanged: (scenarioId) {
                  if (scenarioId != null) {
                    c.onScenarioPicked(scenarioId);
                  }
                },
              ),
              const Spacer(),
              // DSL reference toggle
              IconButton(
                tooltip: legendOpen ? 'Hide DSL reference' : 'DSL reference',
                onPressed: onToggleLegend,
                isSelected: legendOpen,
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                selectedIcon: const Icon(Icons.menu_book, size: 18),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Code editor + optional legend drawer side by side
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: CodeEditor(
                        code: c.dsl,
                        readOnly: false,
                        onChanged: c.onDslChanged,
                        errors: c.parseResult.errors
                            .map(
                              (e) => EditorErrorMark(
                                line: e.line,
                                column: e.column,
                                message: e.message,
                                hint: e.hint,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    _ParseStatusFooter(parseResult: c.parseResult),
                  ],
                ),
              ),
              if (legendOpen) LegendDrawer(onClose: onToggleLegend),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Parse status footer ───────────────────────────────────────────────────────

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

// ── Mascot toggle ─────────────────────────────────────────────────────────────

class _MascotToggle extends StatelessWidget {
  const _MascotToggle({required this.controller});

  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: controller.mascotEnabled,
      builder: (context, enabled, _) {
        return Tooltip(
          message: enabled
              ? 'Mascot on — disable per-scenario animated mascot'
              : 'Mascot off — enable per-scenario animated mascot',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                enabled
                    ? Icons.emoji_emotions
                    : Icons.emoji_emotions_outlined,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Switch(
                value: enabled,
                onChanged: (next) {
                  controller.mascotEnabled.value = next;
                  controller.refresh();
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Temperature slider ────────────────────────────────────────────────────────

class _TemperatureSlider extends StatelessWidget {
  const _TemperatureSlider({required this.notifier});

  final ValueNotifier<double> notifier;

  static const double _min = 0.0;
  static const double _max = 2.0;
  static const int _divisions = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (context, current, _) {
        return Tooltip(
          message: 'Sampling temperature (${current.toStringAsFixed(1)}). '
              'Applies to form generation.',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'T ${current.toStringAsFixed(1)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(
                width: 120,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: current.clamp(_min, _max),
                    min: _min,
                    max: _max,
                    divisions: _divisions,
                    onChanged: (next) => notifier.value = next,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
