import 'package:flutter/material.dart';

import '../../models/outcomes.dart';

/// Renders the [OutcomeNode] tree as a nested card hierarchy.
///
/// Nodes on the [activePath] are highlighted with a coloured border, making
/// the live position in the tree visible at a glance during demos and
/// debugging.
///
/// Typical usage inside a hackathon split-screen demo:
/// ```dart
/// OutcomeTreeView(
///   root: gymgeistTree,
///   activePath: ['account_only', 'with_workout_plan'],
/// )
/// ```
class OutcomeTreeView extends StatelessWidget {
  /// Creates an [OutcomeTreeView].
  ///
  /// [root] is the root of the outcome tree. [activePath] is the ordered list
  /// of node IDs from the root to the currently active node (inclusive on both
  /// ends).
  const OutcomeTreeView({
    required this.root,
    required this.activePath,
    super.key,
  });

  /// The root [OutcomeNode] of the tree to render.
  final OutcomeNode root;

  /// Ordered list of node IDs from root to the currently active node.
  ///
  /// All nodes whose [OutcomeNode.id] appears in this list are rendered with
  /// a highlighted border.
  final List<String> activePath;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _NodeCard(node: root, activePath: activePath, depth: 0),
    );
  }
}

// ── Internal node card ─────────────────────────────────────────────────────────

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.activePath,
    required this.depth,
  });

  final OutcomeNode node;
  final List<String> activePath;
  final int depth;

  bool get _isActive => activePath.contains(node.id);

  String get _nodeTypeLabel => switch (node) {
        Layer() => 'Layer',
        Branch() => 'Branch',
        Outcome() => 'Outcome',
      };

  Color _borderColor(BuildContext context) {
    if (!_isActive) return Colors.transparent;
    return switch (node) {
      Outcome() => Theme.of(context).colorScheme.primary,
      Layer() => Theme.of(context).colorScheme.secondary,
      Branch() => Theme.of(context).colorScheme.tertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isActive;
    final borderColor = _borderColor(context);
    final typeLabel = _nodeTypeLabel;

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? borderColor : Colors.grey.shade300,
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isActive
              ? borderColor.withAlpha(25)
              : Theme.of(context).cardColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ─────────────────────────────────────────────────
              Row(
                children: [
                  _NodeTypeBadge(label: typeLabel, color: borderColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.id,
                      style: TextStyle(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isActive)
                    Icon(
                      Icons.arrow_right_alt,
                      size: 16,
                      color: borderColor,
                    ),
                ],
              ),

              // ── Children ───────────────────────────────────────────────────
              if (node case Layer(:final next) when next != null) ...[
                const SizedBox(height: 8),
                _NodeCard(
                  node: next,
                  activePath: activePath,
                  depth: depth + 1,
                ),
              ],

              if (node case Branch(:final options)) ...[
                const SizedBox(height: 8),
                ...options.map(
                  (opt) => _BranchOptionCard(
                    option: opt,
                    activePath: activePath,
                    depth: depth + 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── BranchOption card ──────────────────────────────────────────────────────────

class _BranchOptionCard extends StatelessWidget {
  const _BranchOptionCard({
    required this.option,
    required this.activePath,
    required this.depth,
  });

  final BranchOption option;
  final List<String> activePath;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: depth * 8.0),
            child: Row(
              children: [
                const Icon(Icons.subdirectory_arrow_right, size: 14),
                const SizedBox(width: 4),
                Text(
                  option.id,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '— ${option.criterion}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _NodeCard(
            node: option.child,
            activePath: activePath,
            depth: depth + 1,
          ),
        ],
      ),
    );
  }
}

// ── Node type badge ────────────────────────────────────────────────────────────

class _NodeTypeBadge extends StatelessWidget {
  const _NodeTypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color == Colors.transparent
              ? Theme.of(context).textTheme.bodySmall?.color
              : color,
        ),
      ),
    );
  }
}
