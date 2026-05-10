import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

/// A side-drawer that surfaces the current contract-filling progress.
///
/// Mounted as the [Scaffold]'s `endDrawer` whenever the workbench's "Progress"
/// AppBar action is the most recently triggered drawer. Subscribes to the
/// active [FormController] (via [controllerRef]) and rebuilds on every session
/// update so it reflects the live state of the form even while the LLM is
/// streaming.
///
/// The drawer answers three questions:
/// 1. **What has been answered so far?** — listed top-to-bottom in submission
///    order with the step title, the user's value, and the engagement signal.
/// 2. **Where are we right now?** — current node id, step counter, and the
///    title of the step that's awaiting input.
/// 3. **How do I throw it all away?** — a "Clear progress" button that calls
///    [FormController.restart], which boots a fresh session against the
///    current DSL.
class ProgressDrawer extends StatelessWidget {
  const ProgressDrawer({required this.controllerRef, super.key});

  /// Live reference to the inner [FormController] hoisted out of [GenuiForm].
  final ValueNotifier<FormController?> controllerRef;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: 420,
      child: SafeArea(
        child: ValueListenableBuilder<FormController?>(
          valueListenable: controllerRef,
          builder: (context, controller, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(theme: theme, hasController: controller != null),
                if (controller == null)
                  const Expanded(child: _NoControllerPlaceholder())
                else
                  Expanded(child: _ProgressBody(controller: controller)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.theme, required this.hasController});

  final ThemeData theme;
  final bool hasController;

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
          Icon(Icons.timeline,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Contract progress', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  hasController
                      ? 'Survives DSL edits — clear to start fresh.'
                      : 'No active form yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _NoControllerPlaceholder extends StatelessWidget {
  const _NoControllerPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Run the form to see contract progress here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Body — listens to the controller ──────────────────────────────────────────

class _ProgressBody extends StatefulWidget {
  const _ProgressBody({required this.controller});

  final FormController controller;

  @override
  State<_ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends State<_ProgressBody> {
  late Session _session;
  StreamSubscription<Session>? _sub;

  @override
  void initState() {
    super.initState();
    _session = widget.controller.currentSession;
    _sub = widget.controller.sessions.listen(_onSession);
  }

  @override
  void didUpdateWidget(covariant _ProgressBody old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      _sub?.cancel();
      _session = widget.controller.currentSession;
      _sub = widget.controller.sessions.listen(_onSession);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onSession(Session session) {
    if (!mounted) return;
    setState(() => _session = session);
  }

  Future<void> _clearProgress() async {
    await widget.controller.restart();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = _session.history;
    final currentStep = widget.controller.currentStep;
    final stepCounter = history.length + 1;
    final contractFields = _session.runningContract.fields;

    final filledRequired = contractFields.entries
        .where((e) => e.value.required && _session.answers[e.key] != null)
        .length;
    final totalRequired =
        contractFields.values.where((f) => f.required).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _StatusRow(
            stepCounter: stepCounter,
            nodeId: _session.currentNode.id,
            statusLabel: _statusLabel(_session.status),
            filledRequired: filledRequired,
            totalRequired: totalRequired,
          ),
        ),
        if (currentStep != null && _session.status == SessionStatus.active)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _CurrentStepCard(
              stepCounter: stepCounter,
              step: currentStep,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      currentStep == null
                          ? 'Waiting for the first step…'
                          : 'No answers yet — submit the current step to begin '
                              'the trail.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, i) {
                    final answer = history[i];
                    return _AnswerRow(index: i + 1, answer: answer);
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  history.isEmpty
                      ? 'Edits to the DSL won\'t reset this — answers stick.'
                      : '${history.length} answer${history.length == 1 ? '' : 's'} retained across edits.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: history.isEmpty ? null : _clearProgress,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear progress'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(SessionStatus status) => switch (status) {
        SessionStatus.active => 'active',
        SessionStatus.completed => 'completed',
        SessionStatus.escalated => 'escalated',
        SessionStatus.abandoned => 'abandoned',
      };
}

// ── Status row (nodes, steps, completion) ────────────────────────────────────

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.stepCounter,
    required this.nodeId,
    required this.statusLabel,
    required this.filledRequired,
    required this.totalRequired,
  });

  final int stepCounter;
  final String nodeId;
  final String statusLabel;
  final int filledRequired;
  final int totalRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusChip(label: 'step', value: 'step $stepCounter'),
        _StatusChip(label: 'node', value: nodeId),
        _StatusChip(label: 'status', value: statusLabel),
        if (totalRequired > 0)
          _StatusChip(
            label: 'required',
            value: '$filledRequired / $totalRequired',
          )
        else
          _StatusChip(
            label: 'required',
            value: '0',
            valueColor: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Current step card ────────────────────────────────────────────────────────

class _CurrentStepCard extends StatelessWidget {
  const _CurrentStepCard({required this.stepCounter, required this.step});

  final int stepCounter;
  final QuizStepSpec step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Awaiting step $stepCounter · ${step.id}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            step.title,
            style: theme.textTheme.bodyMedium,
          ),
          if (step.description != null && step.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              step.description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── One row in the answers list ──────────────────────────────────────────────

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.index, required this.answer});

  final int index;
  final Answer answer;

  String _formatValue() {
    final v = answer.answer;
    final spec = answer.stepSpec;
    if (v == null) return '—';
    if (v is List) {
      if (spec.choices != null) {
        return v
            .map((id) {
              final choice = spec.choices!
                  .where((c) => c.id == id.toString())
                  .firstOrNull;
              return choice?.label ?? id.toString();
            })
            .join(', ');
      }
      return v.join(', ');
    }
    if (spec.choices != null && v is String) {
      final choice =
          spec.choices!.where((c) => c.id == v).firstOrNull;
      return choice?.label ?? v;
    }
    return v.toString();
  }

  Color _engagementColor() => switch (answer.engagement) {
        EngagementSignal.strong => Colors.green,
        EngagementSignal.weak => Colors.amber,
        EngagementSignal.negative => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '$index',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      answer.stepSpec.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _engagementColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              SelectableText(
                _formatValue(),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${answer.stepId} · ${answer.stepSpec.inputType.name}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
