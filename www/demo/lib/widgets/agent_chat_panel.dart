import 'package:flutter/material.dart';

import '../src/agent/agent_message.dart';
import '../state/workbench_controller.dart';
import '../theme/app_spacing.dart';

class AgentChatPanel extends StatefulWidget {
  const AgentChatPanel({required this.controller, super.key});

  final WorkbenchController controller;

  @override
  State<AgentChatPanel> createState() => _AgentChatPanelState();
}

class _AgentChatPanelState extends State<AgentChatPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty || widget.controller.agentStreaming) return;
    _inputController.clear();
    widget.controller.sendToAgent(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final history = widget.controller.agentHistory;
        final streaming = widget.controller.agentStreaming;
        if (history.isNotEmpty) _scrollToBottom();

        final cs = Theme.of(context).colorScheme;

        return Column(
          children: [
            _buildHeader(context, cs),
            Expanded(
              child: history.isEmpty && !streaming
                  ? _buildEmptyState(context, cs)
                  : _buildMessageList(context, history, streaming, cs),
            ),
            _buildInputBar(context, cs, streaming),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          _AgentAvatar(cs: cs),
          const SizedBox(width: AppSpacing.s2),
          Text(
            'DSL Agent',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'New chat',
            onPressed: widget.controller.resetAgentChat,
            icon: const Icon(Icons.refresh, size: 16),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AgentAvatar(cs: cs, size: 44),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Describe the form you want to build.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'The agent knows the full DSL syntax and will generate ready-to-run code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, List<AgentMessage> history,
      bool streaming, ColorScheme cs) {
    final showStreamingBubble =
        streaming && (history.isEmpty || !history.last.isStreaming);

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s5,
        AppSpacing.s3,
      ),
      itemCount: history.length + (showStreamingBubble ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s4),
      itemBuilder: (context, i) {
        if (i == history.length && showStreamingBubble) {
          return const _StreamingBubble();
        }
        return _MessageBubble(
          message: history[i],
          onApplyDsl: widget.controller.applyAgentDsl,
        );
      },
    );
  }

  Widget _buildInputBar(
      BuildContext context, ColorScheme cs, bool streaming) {
    return Padding(
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
                controller: _inputController,
                minLines: 1,
                maxLines: 5,
                enabled: !streaming,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                  hintText:
                      'Describe the form you want — e.g. "3-step onboarding…"',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Material(
              color: streaming ? cs.onSurface.withValues(alpha: 0.12) : cs.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: streaming ? null : _sendMessage,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: streaming
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onSurface.withValues(alpha: 0.38),
                            ),
                          ),
                        )
                      : Icon(Icons.arrow_upward, size: 18, color: cs.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onApplyDsl,
  });

  final AgentMessage message;
  final void Function(String dsl) onApplyDsl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == AgentRole.user;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatar(isUser, cs),
        const SizedBox(width: AppSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'You' : 'DSL Agent',
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
                    topLeft: Radius.circular(AppSpacing.rXs),
                    topRight: Radius.circular(AppSpacing.rL),
                    bottomLeft: Radius.circular(AppSpacing.rL),
                    bottomRight: Radius.circular(AppSpacing.rL),
                  ),
                ),
                child: SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isUser ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
              if (!isUser && message.extractedDsl != null && !message.isStreaming)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s2),
                  child: FilledButton.icon(
                    onPressed: () => onApplyDsl(message.extractedDsl!),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Apply DSL',
                        style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(bool isUser, ColorScheme cs) {
    if (isUser) {
      return Container(
        width: 28,
        height: 28,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.secondaryContainer,
        ),
        alignment: Alignment.center,
        child: Text(
          'YO',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: cs.onSecondaryContainer,
          ),
        ),
      );
    }
    return _AgentAvatar(cs: cs);
  }
}

// ── Agent avatar (gradient ✦) ─────────────────────────────────────────────────

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({required this.cs, this.size = 28});

  final ColorScheme cs;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
      child: Text(
        '✦',
        style: TextStyle(
          fontSize: size * 0.43,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}

// ── Streaming bubble (three animated dots) ────────────────────────────────────

class _StreamingBubble extends StatefulWidget {
  const _StreamingBubble();

  @override
  State<_StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<_StreamingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1200))
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
        _AgentAvatar(cs: cs),
        const SizedBox(width: AppSpacing.s3),
        Row(
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                return Row(
                  children: List.generate(3, (i) {
                    final phase = ((_ctrl.value + i * 0.15) % 1.0);
                    final opacity = 0.3 +
                        0.7 *
                            (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
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
