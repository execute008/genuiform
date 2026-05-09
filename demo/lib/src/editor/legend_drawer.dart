import 'package:flutter/material.dart';

import 'dsl_catalog.dart';

/// A reference panel that lists every DSL primitive by group.
///
/// Embedded as a sidebar inside the editor pane. Each group is a collapsible
/// [ExpansionTile]; entries show the [DslPrimitive.signature] in a monospace
/// font and the [DslPrimitive.description] below.
///
/// The panel is the inert, discoverability-focused counterpart to the inline
/// completion popup. Both read from the same [kDslCatalog] so additions stay
/// in sync.
class LegendDrawer extends StatelessWidget {
  const LegendDrawer({required this.onClose, super.key});

  /// Called when the user clicks the close (X) button in the panel header.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = kDslCatalogByGroup;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(theme: theme, onClose: onClose),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final group in DslGroup.values)
                  if (groups[group]?.isNotEmpty ?? false)
                    _GroupSection(
                      group: group,
                      primitives: groups[group]!,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme, required this.onClose});

  final ThemeData theme;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DSL reference',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Every primitive the workbench parser accepts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.group, required this.primitives});

  final DslGroup group;
  final List<DslPrimitive> primitives;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      initiallyExpanded: group == DslGroup.topLevel,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: Row(
        children: [
          Text(
            group.label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${primitives.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      children: [
        for (final p in primitives) _PrimitiveRow(primitive: p),
      ],
    );
  }
}

class _PrimitiveRow extends StatelessWidget {
  const _PrimitiveRow({required this.primitive});

  final DslPrimitive primitive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            primitive.signature,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            primitive.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
