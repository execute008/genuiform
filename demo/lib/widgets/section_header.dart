import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Uppercase section title used at the top of each quadrant.
class SectionHeader extends StatelessWidget {
  final String title;
  final List<Widget> trailing;
  final Widget? chip;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing = const [],
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (chip != null) ...[
            const SizedBox(width: AppSpacing.s3),
            chip!,
          ],
          const Spacer(),
          ...trailing,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final bool live;
  const StatusChip({super.key, required this.label, this.live = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = live
        ? const Color(0x269FD4A3)
        : cs.surfaceContainerHigh;
    final fg = live ? const Color(0xFF9FD4A3) : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: live ? const Color(0x409FD4A3) : cs.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF9FD4A3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
