import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import '../registry/handoff_registry.dart';
import 'debug_strip.dart';

/// Right-pane preview widget.
///
/// Renders a [GenuiForm] built from the four parsed primitives ([contract],
/// [constraints], [posture], [outcomes]) plus [client] and [model].
///
/// The form's internal [FormController] is hoisted out via
/// [GenuiForm.onControllerCreated] so the [DebugStrip] below can subscribe to
/// live session updates.
///
/// Re-keying this widget (via [ValueKey(_formKey)] in the shell) resets the
/// [FormController] cleanly and triggers the fade-in animation.
class FormPreview extends StatefulWidget {
  const FormPreview({
    required this.contract,
    required this.constraints,
    required this.posture,
    required this.outcomes,
    required this.client,
    required this.model,
    this.handoffMap = const {},
    this.onRestartRequested,
    super.key,
  });

  /// Parsed contract — what fields the LLM may collect.
  final Contract contract;

  /// Parsed constraints — rules the LLM must obey.
  final List<Constraint> constraints;

  /// Parsed posture — tone and pacing settings.
  final Posture posture;

  /// Parsed outcome tree root.
  final OutcomeNode outcomes;

  /// The LLM transport forwarded to the inner form.
  final LlmClient client;

  /// The Vertex AI model string.
  final String model;

  /// Side-table mapping each Outcome.id to its [SimulatedHandoff].
  /// Used to show a handoff toast when [GenuiForm.onComplete] fires.
  final Map<String, SimulatedHandoff> handoffMap;

  /// Called when the user taps "Restart" in the escalation card.
  /// The shell bumps the form key, which re-keys this widget cleanly.
  final VoidCallback? onRestartRequested;

  @override
  State<FormPreview> createState() => _FormPreviewState();
}

class _FormPreviewState extends State<FormPreview>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<FormController?> _controller =
      ValueNotifier<FormController?>(null);

  /// When set, the escalation card replaces the form pane.
  EscalateIf? _activeEscalation;

  /// Drives the fade-in when the form first appears (triggered by re-keying).
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    // Fade in when this widget first appears (after a form rebuild / re-key).
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showHandoffToast(FormResult result) {
    if (!mounted) return;
    final outcomeId = result.reachedOutcome?.id;
    if (outcomeId == null) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final handoff = widget.handoffMap[outcomeId];
    if (handoff == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Form completed — outcome: $outcomeId'),
        ),
      );
      return;
    }

    final icon = _iconForHandoff(handoff);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text('Handoff fired: ${handoff.label}'),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // When an escalation is active, show the escalation card instead of form.
    if (_activeEscalation != null) {
      return _EscalationCard(
        trigger: _activeEscalation!.trigger,
        onRestart: () {
          setState(() => _activeEscalation = null);
          widget.onRestartRequested?.call();
        },
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GenuiForm(
              contract: widget.contract,
              constraints: widget.constraints,
              posture: widget.posture,
              outcomes: widget.outcomes,
              client: widget.client,
              model: widget.model,
              onControllerCreated: (c) => _controller.value = c,
              onComplete: _showHandoffToast,
              onEscalation: (rule) {
                if (!mounted) return;
                setState(() => _activeEscalation = rule);
              },
              onError: (err) {
                if (!mounted) return;
                // Don't surface raw transport errors on screen — Vertex's
                // 4xx/5xx error envelopes can echo project IDs, region info,
                // or correlation hints that would be visible on a projector.
                debugPrint('GenuiForm error: $err');
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Form error — see browser console for details.'),
                    ),
                  );
              },
            ),
          ),
          ValueListenableBuilder<FormController?>(
            valueListenable: _controller,
            builder: (context, controller, _) {
              if (controller == null) {
                return const _DebugStripPlaceholder();
              }
              return DebugStrip(controller: controller);
            },
          ),
        ],
      ),
    );
  }
}

// ── Escalation card ────────────────────────────────────────────────────────────

class _EscalationCard extends StatelessWidget {
  const _EscalationCard({
    required this.trigger,
    required this.onRestart,
  });

  final String trigger;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.support_agent,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Form ended due to escalation:',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  trigger,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Icon mapping ───────────────────────────────────────────────────────────────

/// Maps a [SimulatedHandoff.icon] string to a Flutter [IconData].
///
/// The icon strings are the historical registry keys (kept as strings to avoid
/// breaking parser tests). The mapping is done lazily at render time.
IconData _iconForHandoff(SimulatedHandoff handoff) {
  return switch (handoff.icon) {
    'calendar' => Icons.calendar_today,
    'mail' => Icons.mail_outline,
    'door' => Icons.logout,
    'home' => Icons.home_outlined,
    'dumbbell' => Icons.fitness_center,
    'utensils' => Icons.restaurant,
    'scale' => Icons.monitor_weight_outlined,
    'check' => Icons.check_circle_outline,
    _ => Icons.flag_outlined,
  };
}

// ── Debug strip placeholder ────────────────────────────────────────────────────

class _DebugStripPlaceholder extends StatelessWidget {
  const _DebugStripPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Text(
        'Debug strip — waiting for form to start…',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}
