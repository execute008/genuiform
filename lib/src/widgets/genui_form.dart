import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/constraints.dart';
import '../models/contract.dart';
import '../models/form_result.dart';
import '../models/outcomes.dart';
import '../models/posture.dart';
import '../models/quiz_input_type.dart';
import '../models/session.dart';
import '../models/session_status.dart';
import '../models/step_event.dart';
import '../llm/gemini_api_client.dart';
import '../llm/llm_client.dart';
import '../strategies/form_config.dart';
import '../strategies/generative_strategy.dart';
import '../strategies/strategy.dart';
import 'form_controller.dart';
import 'step_renderer.dart';
import 'streaming_indicator.dart';

/// The top-level drop-in form widget.
///
/// [GenuiForm] composes [FormController], [StepRenderer], and
/// [StreamingIndicator] into a complete adaptive form UI. Consumers provide
/// the four primitives (contract, constraints, posture, outcomes) plus an LLM
/// client and model string. The form handles the rest.
///
/// ### Layout (top to bottom)
///
/// 1. **Progress bar** — [LinearProgressIndicator] based on filled required
///    fields vs. total required fields in the running contract.
/// 2. **[StreamingIndicator]** — shown inline while the controller is awaiting
///    a strategy response.
/// 3. **[StepRenderer]** — renders the current step's input widget.
/// 4. **"Next" button** — calls [FormController.submitAnswer].
/// 5. **Result panel** — shown when [Session.status] is [SessionStatus.completed].
/// 6. **Escalation panel** — shown when [Session.status] is [SessionStatus.escalated].
/// 7. **Error banner** — shown on [StreamError]; includes a Retry button.
///
/// ### Example
///
/// ```dart
/// GenuiForm(
///   contract: leadContract,
///   constraints: [NeverCollect('payment_info'), MaxSteps(8)],
///   posture: Posture.salesDiscovery(),
///   outcomes: leadOutcomes,
///   client: geminiClient,
///   model: 'gemini-2.5-flash',
///   onComplete: (result) => handleResult(result),
/// )
/// ```
class GenuiForm extends StatefulWidget {
  const GenuiForm({
    required this.contract,
    required this.constraints,
    required this.posture,
    required this.outcomes,
    required this.client,
    required this.model,
    this.temperature = 0.7,
    this.strategy,
    this.onComplete,
    this.onEscalation,
    this.onError,
    this.onControllerCreated,
    this.scenarioId,
    super.key,
  });

  /// The fields this form must collect for completion.
  final Contract contract;

  /// Hard invariants checked every turn.
  final List<Constraint> constraints;

  /// Soft behavioural knobs interpreted by the LLM.
  final Posture posture;

  /// The outcome tree — where the form can end up.
  final OutcomeNode outcomes;

  /// The LLM transport.
  final LlmClient client;

  /// The Gemini model ID string (e.g. `'gemini-2.5-flash'`).
  final String model;

  /// Sampling temperature forwarded to the underlying [FormConfig].
  /// Defaults to `0.7`.
  final double temperature;

  /// The strategy to use. Defaults to [GenerativeStrategy] when `null`.
  final Strategy? strategy;

  /// Called when an [OutcomeReached] event fires with the completed result.
  final void Function(FormResult)? onComplete;

  /// Called when an [EscalationFired] event fires.
  final void Function(EscalateIf)? onEscalation;

  /// Called when a [StreamError] event fires.
  final void Function(Object)? onError;

  /// Called once after the internal [FormController] is created.
  ///
  /// Lets consumers subscribe to [FormController.sessions] / [FormController.events]
  /// from outside the widget (e.g. a debug strip rendered next to the form).
  /// The controller's lifecycle is owned by [GenuiForm] — do not call
  /// [FormController.dispose] on it.
  final void Function(FormController controller)? onControllerCreated;

  /// Optional scenario key used to drive the per-scenario animated SVG mascot
  /// rendered below the "Next" button. When non-null and [client] is a
  /// [GeminiApiClient], a fresh mascot is requested on initial mount and on
  /// every "Next" press. When null (or when [client] is a mock), no mascot is
  /// rendered.
  final String? scenarioId;

  @override
  State<GenuiForm> createState() => _GenuiFormState();
}

class _GenuiFormState extends State<GenuiForm>
    with SingleTickerProviderStateMixin {
  late FormController _controller;
  dynamic _currentValue;
  StepEvent? _lastEvent;
  String _mascotSvg = '';
  bool _mascotLoading = false;

  /// Drives the bob (vertical bounce) animation for the mascot. flutter_svg
  /// does not execute CSS animations baked into the SVG itself, so the bob
  /// is applied Flutter-side via Transform.translate.
  late final AnimationController _bobController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initController();
    final scenarioId = widget.scenarioId;
    if (scenarioId != null) {
      _regenerateMascot(scenarioId);
    }
  }

  void _initController() {
    _controller = FormController(
      config: _buildConfig(),
      strategy: widget.strategy ?? GenerativeStrategy(),
    );
    _controller.events.listen(_handleEvent);
    widget.onControllerCreated?.call(_controller);
    _controller.start();
  }

  FormConfig _buildConfig() => FormConfig(
        contract: widget.contract,
        constraints: widget.constraints,
        posture: widget.posture,
        outcomes: widget.outcomes,
        client: widget.client,
        model: widget.model,
        temperature: widget.temperature,
      );

  @override
  void didUpdateWidget(covariant GenuiForm old) {
    super.didUpdateWidget(old);

    // Detect a meaningful change in the four parsed primitives. If only the
    // client identity changed (e.g. mock-vs-real swap) we treat that as a
    // config-replacing event too, since the underlying transport has shifted.
    final configChanged = old.contract != widget.contract ||
        !_listsEqual(old.constraints, widget.constraints) ||
        old.posture != widget.posture ||
        old.outcomes != widget.outcomes ||
        !identical(old.client, widget.client) ||
        old.model != widget.model ||
        old.temperature != widget.temperature;

    if (configChanged) {
      // Hand the new config to the existing controller — it preserves the
      // session and re-asks the LLM for the current step against the updated
      // DSL. If the current node disappeared from the new outcome tree,
      // [FormController.rebuildConfig] resets cleanly.
      _controller.rebuildConfig(_buildConfig());
      // Reset the pending input value — the regenerated step may use a
      // different input type, and a stale value would be misleading.
      _currentValue = null;
    }
  }

  bool _listsEqual<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _handleEvent(StepEvent event) {
    if (!mounted) return;
    setState(() => _lastEvent = event);

    // Consumer callbacks may navigate or otherwise dispose this widget. Defer
    // them past the current frame and re-check `mounted`, so a callback that
    // calls e.g. `Navigator.replace(...)` inside its handoff doesn't trigger
    // build/setState on a disposed [State].
    void deferToNextFrame(VoidCallback fn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        fn();
      });
    }

    switch (event) {
      case OutcomeReached(:final result):
        if (widget.onComplete != null) {
          deferToNextFrame(() => widget.onComplete!(result));
        }
      case EscalationFired(:final rule):
        if (widget.onEscalation != null) {
          deferToNextFrame(() => widget.onEscalation!(rule));
        }
      case StreamError(:final error):
        if (widget.onError != null) {
          deferToNextFrame(() => widget.onError!(error));
        }
      case StepReady():
        // Reset current value when a new step appears.
        _currentValue = null;
      case LayerComplete():
      case BranchTaken():
        break;
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submitAnswer() {
    final step = _controller.currentStep;
    if (step == null) return;
    _controller.submitAnswer(_currentValue);

    final scenarioId = widget.scenarioId;
    if (scenarioId != null) {
      _regenerateMascot(scenarioId);
    }
  }

  Future<void> _regenerateMascot(String scenarioKey) async {
    final client = widget.client;
    if (client is! GeminiApiClient) {
      debugPrint(
        'GenuiForm: skipping mascot — client is ${client.runtimeType}, '
        'not GeminiApiClient.',
      );
      return;
    }

    setState(() => _mascotLoading = true);

    try {
      final svg = await client.generateMascotSvg(scenarioKey);
      if (!mounted) return;
      debugPrint(
        'GenuiForm: mascot for "$scenarioKey" — '
        '${svg.isEmpty ? "EMPTY (keeping previous)" : "${svg.length} chars"}',
      );
      setState(() {
        // If the new fetch failed (timeout, no SVG block), keep the previous
        // mascot rather than blanking it. A missing mascot is worse UX than
        // a slightly stale one.
        if (svg.isNotEmpty) _mascotSvg = svg;
        _mascotLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('GenuiForm._regenerateMascot error: $e — keeping previous');
      setState(() => _mascotLoading = false);
    }
  }

  Widget _buildMascot() {
    // Show the spinner only on first load (no mascot to display yet). When
    // refreshing, keep the existing mascot visible so it doesn't flash out.
    if (_mascotLoading && _mascotSvg.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_mascotSvg.isEmpty) {
      return const SizedBox.shrink();
    }

    // Animate vertical bob via Flutter (flutter_svg ignores any <style> /
    // @keyframes embedded in the SVG itself).
    return AnimatedBuilder(
      key: ValueKey(_mascotSvg.hashCode),
      animation: _bobController,
      builder: (context, child) {
        final dy = -6.0 * math.sin(_bobController.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: SvgPicture.string(
        _mascotSvg,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
      ),
    );
  }

  void _retry() {
    _controller.retryStrategy();
  }

  void _restart() {
    setState(() {
      _currentValue = null;
      _lastEvent = null;
    });
    _controller.restart();
  }

  /// Computes progress: filled required fields / total required fields.
  ///
  /// ⚡ BOLT OPTIMIZATION: Use the pre-computed runningContract from the
  /// session instead of re-walking the tree with OutcomeNavigator.
  /// This reduces the complexity from O(TreeDepth) to O(1) per UI rebuild,
  /// avoiding redundant tree traversals and object allocations.
  double _computeProgress(Session session) {
    final contract = session.runningContract;

    final total =
        contract.fields.values.where((f) => f.required).length;
    if (total == 0) return 0.0;

    final filled = contract.fields.entries
        .where((e) => e.value.required && session.answers[e.key] != null)
        .length;

    return filled / total;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Session>(
      stream: _controller.sessions,
      initialData: _controller.currentSession,
      builder: (context, snapshot) {
        final session = snapshot.data ?? _controller.currentSession;
        return _buildBody(context, session);
      },
    );
  }

  Widget _buildBody(BuildContext context, Session session) {
    // ── Terminal: completed ─────────────────────────────────────────────────
    if (session.status == SessionStatus.completed) {
      return _ResultPanel(
        session: session,
        onRestart: _restart,
      );
    }

    // ── Terminal: escalated ─────────────────────────────────────────────────
    if (session.status == SessionStatus.escalated) {
      return const _EscalationPanel();
    }

    final progress = _computeProgress(session);
    final currentStep = _controller.currentStep;
    final isAwaiting = _controller.isAwaiting;
    final lastEvent = _lastEvent;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Progress bar ───────────────────────────────────────────────
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 16),

          // ── Streaming indicator ────────────────────────────────────────
          if (isAwaiting) ...[
            const Center(child: StreamingIndicator(label: 'Thinking…')),
            const SizedBox(height: 16),
          ],

          // ── Step renderer ──────────────────────────────────────────────
          if (currentStep != null) ...[
            Text(
              currentStep.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            StepRenderer(
              spec: currentStep,
              value: _currentValue,
              onChanged: (v) => setState(() => _currentValue = v),
              onSubmit: _submitAnswer,
            ),
          ] else if (!isAwaiting && lastEvent is! StreamError) ...[
            // No step yet, not awaiting, and no error — show a placeholder
            const Center(child: CircularProgressIndicator()),
          ],

          const Spacer(),

          // ── Error banner ───────────────────────────────────────────────
          if (lastEvent is StreamError) ...[
            _ErrorBanner(
              error: lastEvent.error,
              onRetry: _retry,
            ),
            const SizedBox(height: 12),
          ],

          // ── Next button ────────────────────────────────────────────────
          // Hidden for info/consent steps where the InfoPanel's Continue
          // button is the sole CTA and already submits.
          if (currentStep != null &&
              !isAwaiting &&
              currentStep.inputType != QuizInputType.noneJustInformation) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton(
                onPressed: _submitAnswer,
                child: const Text('Next'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildMascot(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-panels ────────────────────────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.session, required this.onRestart});

  final Session session;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final outcomeId = session.reachedOutcome?.id ?? '—';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            outcomeId,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your form has been completed.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onRestart,
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}

class _EscalationPanel extends StatelessWidget {
  const _EscalationPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.support_agent, size: 64),
          SizedBox(height: 16),
          Text(
            "Thanks, we'll take it from here.",
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'A member of our team will be in touch shortly.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
