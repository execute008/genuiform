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
        if (history.isNotEmpty) {
          _scrollToBottom();
        }
        return _buildPanel(context, history);
      },
    );
  }

  Widget _buildPanel(BuildContext context, List<AgentMessage> history) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, cs),
          const Divider(height: 1),
          Expanded(
            child: history.isEmpty
                ? _buildEmptyState(context, cs)
                : _buildMessageList(context, history, cs),
          ),
          const Divider(height: 1),
          _buildInputBar(context, cs),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy, size: 18, color: cs.primary),
          const SizedBox(width: AppSpacing.s2),
          Text(
            'DSL Agent',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'New chat',
            onPressed: widget.controller.resetAgentChat,
            icon: const Icon(Icons.refresh, size: 18),
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
        child: Text(
          'Describe the form you want to build.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(
      BuildContext context, List<AgentMessage> history, ColorScheme cs) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s3, horizontal: AppSpacing.s3),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final message = history[index];
        return _MessageBubble(
          message: message,
          onApplyDsl: widget.controller.applyAgentDsl,
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context, ColorScheme cs) {
    final streaming = widget.controller.agentStreaming;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
      color: cs.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              enabled: !streaming,
              decoration: InputDecoration(
                hintText: 'Ask about the DSL...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          IconButton(
            tooltip: 'Send',
            onPressed: streaming ? null : _sendMessage,
            icon: streaming
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 18),
          ),
        ],
      ),
    );
  }
}

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.smart_toy,
                      size: 14, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.s1),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
                  decoration: BoxDecoration(
                    color: isUser
                        ? cs.primaryContainer
                        : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isUser ? 12 : 2),
                      bottomRight: Radius.circular(isUser ? 2 : 12),
                    ),
                  ),
                  child: message.isStreaming && message.text.isEmpty
                      ? _StreamingIndicator()
                      : SelectableText(
                          message.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: isUser
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                            height: 1.5,
                          ),
                        ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: AppSpacing.s1),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(Icons.person,
                      size: 14, color: cs.onSecondaryContainer),
                ),
              ],
            ],
          ),
          if (!isUser && message.isStreaming && message.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: _StreamingIndicator(),
            ),
          if (!isUser && message.extractedDsl != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: AppSpacing.s1),
              child: FilledButton.icon(
                onPressed: () => onApplyDsl(message.extractedDsl!),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Apply DSL', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreamingIndicator extends StatefulWidget {
  @override
  State<_StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<_StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _opacityAnimation =
        Tween<double>(begin: 0.3, end: 1.0).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
