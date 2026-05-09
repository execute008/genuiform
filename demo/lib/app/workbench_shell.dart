import 'package:flutter/material.dart';

import '../state/workbench_controller.dart';
import '../theme/app_spacing.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/chat_panel.dart';
import '../widgets/form_preview_panel.dart';
import '../widgets/personas_panel.dart';

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
                              child: ChatPanel(controller: _controller),
                            ),
                            Divider(color: cs.outlineVariant, height: 1),
                            Visibility(
                              visible: false,
                              child: SizedBox(
                                height: 480,
                                child:
                                    PersonasPanel(controller: _controller),
                              ),
                            ),
                            Divider(color: cs.outlineVariant, height: 1),
                            SizedBox(
                              height: 720,
                              child: FormPreviewPanel(
                                controller: _controller,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left column: chat + personas stacked
                          SizedBox(
                            width: constraints.maxWidth * 0.38,
                            child: ChatPanel(controller: _controller),
                          ),
                          VerticalDivider(
                            color: cs.outlineVariant,
                            width: 1,
                          ),
                          // Right column: form preview
                          Expanded(
                            child: FormPreviewPanel(controller: _controller),
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
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [cs.tertiary, cs.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'genu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'i',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: cs.primary,
                ),
              ),
              Text(
                'form workbench',
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
          Text(
            'Project: untitled · tdl/v3',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const Spacer(),
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
          TextButton.icon(
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text('Constraints'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Work in progress')),
              );
            },
          ),
          const SizedBox(width: AppSpacing.s2),
          TextButton.icon(
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('Tokens'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Work in progress')),
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
