import 'package:flutter/material.dart';

import '../models/persona.dart';
import '../state/workbench_controller.dart';
import '../theme/app_spacing.dart';
import 'persona_avatar.dart';
import 'section_header.dart';

class PersonasPanel extends StatelessWidget {
  final WorkbenchController controller;
  const PersonasPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = controller.visiblePersonas;

    return Column(
      children: [
        SectionHeader(
          title: 'Personas',
          chip: StatusChip(label: '${visible.length} simulated'),
          trailing: [
            TextButton.icon(
              icon: const Icon(Icons.shuffle, size: 14),
              label: const Text('Shuffle'),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s5,
              vertical: AppSpacing.s4,
            ),
            itemCount: visible.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.s3),
            itemBuilder: (context, i) {
              final p = visible[i];
              final active = p.id == controller.activePersonaId;
              return _PersonaCard(
                persona: p,
                active: active,
                onTap: () => controller.setActivePersona(p.id),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s5,
            AppSpacing.s3,
            AppSpacing.s5,
            AppSpacing.s5,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Drives split-screen adaptation demo',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Generate persona'),
                onPressed: controller.addPersona,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final Persona persona;
  final bool active;
  final VoidCallback onTap;
  const _PersonaCard({
    required this.persona,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: active ? cs.surfaceContainerHigh : cs.surfaceContainer,
      borderRadius: BorderRadius.circular(AppSpacing.rL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rL),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.rL),
            border: Border.all(
              color: active ? cs.primary : Colors.transparent,
              width: active ? 1 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.08),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              PersonaAvatar(seed: persona.seed, hue: persona.hue),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            persona.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (persona.tag != null) ...[
                          const SizedBox(width: AppSpacing.s2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              persona.tag!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: cs.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      persona.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    _EngagementBars(level: persona.engagement),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? cs.primary : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Icon(
                  active ? Icons.visibility : Icons.arrow_forward,
                  size: 16,
                  color: active ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngagementBars extends StatelessWidget {
  final Engagement level;
  const _EngagementBars({required this.level});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color color;
    int bars;
    String label;
    switch (level) {
      case Engagement.strong:
        color = const Color(0xFF9FD4A3);
        bars = 3;
        label = 'High engagement';
        break;
      case Engagement.medium:
        color = const Color(0xFFFFC77A);
        bars = 2;
        label = 'Medium engagement';
        break;
      case Engagement.weak:
        color = const Color(0xFFFFB4AB);
        bars = 1;
        label = 'Low engagement';
        break;
    }
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          Container(
            width: 3,
            height: 6 + i * 3.0,
            decoration: BoxDecoration(
              color: i < bars ? color : cs.outlineVariant,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < 2) const SizedBox(width: 2),
        ],
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
