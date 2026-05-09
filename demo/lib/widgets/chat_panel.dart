import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../state/workbench_controller.dart';
import '../theme/app_spacing.dart';
import 'section_header.dart';

class ChatPanel extends StatefulWidget {
  final WorkbenchController controller;
  const ChatPanel({super.key, required this.controller});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  static const _suggestions = [
    'a medical intake form for a clinic',
    '3-step onboarding for a fintech app',
    'NPS feedback that adapts to engagement',
  ];

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
    await widget.controller.submitPrompt(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.controller;
    return Column(
      children: [
        SectionHeader(
          title: 'Prompt',
          chip: const StatusChip(label: 'gemini-1.5-pro'),
          trailing: [
            IconButton(
              icon: const Icon(Icons.history, size: 18),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Work in progress')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Work in progress')),
                );
              },
            ),
          ],
        ),
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
                          'Describe the form you want — e.g. “a 3-step onboarding…”',
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
