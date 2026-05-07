import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

/// A horizontal strip below the form showing live session diagnostics.
///
/// Displays three [Card] widgets:
/// - **Step**: current step count (history length + 1)
/// - **Engagement**: the latest [EngagementSignal] with a colour-coded dot
/// - **Path**: the `id` of the [Session.currentNode]
///
/// Subscribes to [FormController.sessions] and rebuilds on every session
/// update.
class DebugStrip extends StatefulWidget {
  const DebugStrip({required this.controller, super.key});

  /// The controller whose [FormController.sessions] stream is subscribed to.
  final FormController controller;

  @override
  State<DebugStrip> createState() => _DebugStripState();
}

class _DebugStripState extends State<DebugStrip> {
  late Session _session;

  @override
  void initState() {
    super.initState();
    _session = widget.controller.currentSession;
    widget.controller.sessions.listen(_onSession);
  }

  void _onSession(Session session) {
    if (!mounted) return;
    setState(() => _session = session);
  }

  @override
  Widget build(BuildContext context) {
    final stepCount = _session.history.length;
    final signal = _session.lastSignal;
    final nodeId = _session.currentNode.id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          _DebugCard(
            label: 'Step',
            value: 'step ${stepCount + 1}',
          ),
          const SizedBox(width: 8),
          _EngagementCard(signal: signal),
          const SizedBox(width: 8),
          _DebugCard(
            label: 'Path',
            value: nodeId,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _DebugCard extends StatelessWidget {
  const _DebugCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({required this.signal});

  final EngagementSignal signal;

  Color _dotColor(BuildContext context) {
    return switch (signal) {
      EngagementSignal.strong => Colors.green,
      EngagementSignal.weak => Colors.amber,
      EngagementSignal.negative => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Engagement',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _dotColor(context),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  signal.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
