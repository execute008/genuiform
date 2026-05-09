import 'package:flutter/material.dart';

import 'package:genuiform_a2ui/genuiform_a2ui.dart';

import '../state/workbench_controller.dart';
import '../theme/app_spacing.dart';
import '../widgets/api_key_dialog.dart';
import '../src/editor/code_editor.dart';
import '../src/editor/progress_drawer.dart';
import '../src/preview/form_preview.dart';
import '../src/scenarios/scenarios.dart';
import '../models/chat_message.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WorkbenchShell extends StatefulWidget {
  const WorkbenchShell({super.key});

  @override
  State<WorkbenchShell> createState() => _WorkbenchShellState();
}

class _WorkbenchShellState extends State<WorkbenchShell> {
  final WorkbenchController _controller = WorkbenchController();
  
  @override
  void initState() {
    super.initState();
    _controller.init();
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
                              child: _UnifiedPanel(controller: _controller),
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
                          // Left column: unified panel
                          SizedBox(
                            width: constraints.maxWidth * 0.38,
                            child: _UnifiedPanel(controller: _controller),
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
          IconButton(
            tooltip: 'Contract progress',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => Container(
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
          const SizedBox(width: AppSpacing.s2),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.auto_awesome, size: 14),
            label: const Text('Share'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Work in progress')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UnifiedPanel extends StatefulWidget {
  final WorkbenchController controller;
  const _UnifiedPanel({required this.controller});
  
  @override
  State<_UnifiedPanel> createState() => _UnifiedPanelState();
}

class _UnifiedPanelState extends State<_UnifiedPanel> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? _composer.text).trim();
    if (t.isEmpty) return;
    _composer.clear();
    // Just add to history without triggering form generation
    widget.controller.addMockMessage(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.controller;
    
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        return Column(
          children: [
            // Unified header - always visible
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  // Text(
                  //   'PROMPT',
                  //   style: TextStyle(
                  //     fontSize: 11,
                  //     fontWeight: FontWeight.w600,
                  //     letterSpacing: 0.5,
                  //     color: cs.onSurfaceVariant,
                  //   ),
                  // ),
                  const SizedBox(width: AppSpacing.s3),
                  // Model selector dropdown
                  ValueListenableBuilder<String>(
                    valueListenable: c.model,
                    builder: (context, current, _) {
                      return DropdownButton<String>(
                        value: current,
                        underline: const SizedBox.shrink(),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                        items: WorkbenchController.candidateModels.map((m) => DropdownMenuItem<String>(
                          value: m,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(m),
                          ),
                        )).toList(),
                        onChanged: (next) {
                          if (next != null && next != current) {
                            c.model.value = next;
                          }
                        },
                      );
                    },
                  ),
                  const Spacer(),
                  // Inactive history icon
                  IconButton(
                    icon: Icon(Icons.history, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Work in progress')),
                      );
                    },
                  ),
                  // Inactive new thread icon
                  IconButton(
                    icon: Icon(Icons.add, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Work in progress')),
                      );
                    },
                  ),
                  // Toggle button for Chat/Code
                  c.showDslEditor
                    ? TextButton.icon(
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('← Chat'),
                        onPressed: c.toggleDslEditor,
                      )
                    : FilledButton.tonalIcon(
                        icon: const Icon(Icons.code, size: 16),
                        label: const Text('Edit code'),
                        onPressed: c.toggleDslEditor,
                      ),
                ],
              ),
            ),
            // Body switches between chat and code editor
            Expanded(
              child: c.showDslEditor
                ? _buildCodeEditor(context)
                : _buildChatView(context),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildCodeEditor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.controller;
    
    return Column(
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
              Text('Scenario:', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(width: AppSpacing.s2),
              DropdownButton<String>(
                value: c.currentScenarioId,
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 13, color: cs.onSurface),
                items: kScenarios.map((s) => DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(s.name),
                )).toList(),
                onChanged: (scenarioId) {
                  if (scenarioId != null) {
                    c.onScenarioPicked(scenarioId);
                  }
                },
              ),
            ],
          ),
        ),
        // Code editor
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
      ],
    );
  }
  
  Widget _buildChatView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.controller;
    
    return Column(
      children: [
        // Chat messages feed
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s5,
              AppSpacing.s5,
              AppSpacing.s5,
              AppSpacing.s3,
            ),
            itemCount: c.history.length + (c.generating ? 1 : 0),
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.s4),
            itemBuilder: (context, i) {
              if (i == c.history.length && c.generating) {
                return c.streamingText.isNotEmpty 
                  ? _MessageBubble(
                      message: ChatMessage(
                        role: ChatRole.ai,
                        text: c.streamingText,
                      ),
                      onTapFollowup: _send,
                    )
                  : _StreamingBubble();
              }
              return _MessageBubble(
                message: c.history[i],
                onTapFollowup: _send,
              );
            },
          ),
        ),
        // Composer input
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s2,
            AppSpacing.s5,
            AppSpacing.s5,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.rXl),
              border: Border.all(color: cs.outlineVariant),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s2,
              AppSpacing.s2,
              AppSpacing.s2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 5,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s2,
                      ),
                      hintText:
                          'Describe the form you want — e.g. "a 3-step onboarding…"',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file, size: 18),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Work in progress')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.mic_none, size: 18),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Work in progress')),
                    );
                  },
                ),
                Material(
                  color: cs.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: c.generating ? null : () => _send(),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.arrow_upward,
                        size: 18,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String) onTapFollowup;
  const _MessageBubble({required this.message, required this.onTapFollowup});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isUser
                ? null
                : LinearGradient(
                    colors: [cs.tertiary, cs.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isUser ? cs.secondaryContainer : null,
          ),
          alignment: Alignment.center,
          child: Text(
            isUser ? 'YO' : '✦',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isUser ? cs.onSecondaryContainer : cs.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'You' : 'Gemini',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s3,
                ),
                decoration: BoxDecoration(
                  color: isUser ? cs.primaryContainer : cs.surfaceContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(AppSpacing.rL),
                    bottomLeft: Radius.circular(AppSpacing.rL),
                    bottomRight: Radius.circular(AppSpacing.rL),
                  ),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isUser ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
              if (message.followups != null && message.followups!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s3),
                  child: Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      for (final s in message.followups!)
                        _Chip(
                          label: s,
                          accent: true,
                          onTap: () => onTapFollowup(s),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreamingBubble extends StatefulWidget {
  @override
  State<_StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<_StreamingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [cs.tertiary, cs.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text('✦', style: TextStyle(color: cs.onPrimary)),
        ),
        const SizedBox(width: AppSpacing.s3),
        Row(
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  children: List.generate(3, (i) {
                    final phase = ((_ctrl.value + i * 0.15) % 1.0);
                    final opacity = 0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withValues(alpha: opacity),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(width: AppSpacing.s2),
            Text(
              'Thinking…',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool accent;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppSpacing.rS),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rS),
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.rS),
            border: Border.all(color: cs.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 12,
                color: accent ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: accent ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
