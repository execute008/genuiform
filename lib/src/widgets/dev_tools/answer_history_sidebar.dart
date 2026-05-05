import 'package:flutter/material.dart';

import '../../models/answer.dart';
import '../../models/engagement_signal.dart';

/// Renders a scrollable list of [Answer] records from a session history.
///
/// Each row shows the step title, the user's answer value, and an
/// engagement badge colour-coded by signal:
/// - **strong** → green
/// - **weak** → amber
/// - **negative** → red
///
/// Designed as a collapsible sidebar in the hackathon split-screen demo.
///
/// Example:
/// ```dart
/// AnswerHistorySidebar(history: controller.currentSession.history)
/// ```
class AnswerHistorySidebar extends StatelessWidget {
  /// Creates an [AnswerHistorySidebar].
  const AnswerHistorySidebar({required this.history, super.key});

  /// The ordered list of answers to display. Matches [Session.history].
  final List<Answer> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(child: Text('No answers yet.'));
    }

    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final answer = history[index];
        return _AnswerRow(answer: answer, index: index + 1);
      },
    );
  }
}

// ── Single answer row ──────────────────────────────────────────────────────────

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.answer, required this.index});

  final Answer answer;
  final int index;

  @override
  Widget build(BuildContext context) {
    final valueText = _formatValue(answer.answer);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Step index ───────────────────────────────────────────────────
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),

          // ── Step title + value ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  answer.stepSpec.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (valueText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    valueText,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Engagement badge ─────────────────────────────────────────────
          _EngagementBadge(signal: answer.engagement),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is List) return value.join(', ');
    return value.toString();
  }
}

// ── Engagement badge ───────────────────────────────────────────────────────────

/// A coloured chip indicating the [EngagementSignal] for an answer.
///
/// - [EngagementSignal.strong] → green
/// - [EngagementSignal.weak] → amber
/// - [EngagementSignal.negative] → red
class _EngagementBadge extends StatelessWidget {
  const _EngagementBadge({required this.signal});

  final EngagementSignal signal;

  Color get _color => switch (signal) {
        EngagementSignal.strong => Colors.green,
        EngagementSignal.weak => Colors.amber,
        EngagementSignal.negative => Colors.red,
      };

  String get _label => switch (signal) {
        EngagementSignal.strong => 'strong',
        EngagementSignal.weak => 'weak',
        EngagementSignal.negative => 'neg',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color, width: 1),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
