import 'dart:async';

import '../models/answer.dart';
import '../models/engagement_signal.dart';
import '../models/quiz_step_spec.dart';
import '../models/session.dart';
import '../models/session_status.dart';
import '../models/step_event.dart';
import '../runtime/constraint_enforcer.dart';
import '../runtime/engagement_reader.dart';
import '../runtime/outcome_navigator.dart';
import '../strategies/form_config.dart';
import '../strategies/strategy.dart';

/// The state engine for a [GenuiForm] session.
///
/// [FormController] owns the [Session], drives [Strategy.nextStep] calls, and
/// exposes a broadcast [Stream<Session>] that the widget layer listens to.
///
/// ### Lifecycle
///
/// 1. Create a [FormController] with a [FormConfig] and a [Strategy].
/// 2. Call [start] to kick off the first LLM call.
/// 3. Call [submitAnswer] after each user interaction.
/// 4. Optionally call [back] to rewind or [restart] to reset.
/// 5. Call [dispose] when the widget is unmounted.
///
/// ### Back (v1 simplification)
///
/// [back] pops the last [Answer] from history and restores the prior step
/// without an additional LLM call. This means the question text is shown
/// again exactly as the LLM originally worded it.
///
/// **v2 enhancement (not implemented):** re-invoke [Strategy.nextStep] from
/// the rewound [Session] to regenerate a contextually updated question,
/// allowing the LLM to rephrase given the removed answer.
class FormController {
  FormController({
    required this.config,
    required Strategy strategy,
  }) : _strategy = strategy;

  /// The frozen configuration for this form session.
  final FormConfig config;

  final Strategy _strategy;

  late Session _session = _buildInitialSession();
  QuizStepSpec? _currentStep;
  bool _isAwaiting = false;
  bool _disposed = false;

  final _sessionsCtrl = StreamController<Session>.broadcast();
  final _eventsCtrl = StreamController<StepEvent>.broadcast();

  final _engagementReader = EngagementReader();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Broadcast stream of [Session] snapshots — emits after each turn.
  Stream<Session> get sessions => _sessionsCtrl.stream;

  /// Broadcast stream of raw [StepEvent]s from the strategy.
  Stream<StepEvent> get events => _eventsCtrl.stream;

  /// Whether the controller is currently awaiting a strategy response.
  bool get isAwaiting => _isAwaiting;

  /// The current [Session] snapshot.
  Session get currentSession => _session;

  /// The most recently rendered step, or `null` before the first [StepReady]
  /// event.
  QuizStepSpec? get currentStep => _currentStep;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Starts the form by invoking [Strategy.nextStep] with the initial
  /// [Session]. The strategy will emit the first [StepReady] event.
  Future<void> start() async {
    _session = _buildInitialSession();
    _sessionsCtrl.add(_session);
    await _runStrategyLoop();
  }

  /// Submits [value] as the answer to [currentStep] and advances the form.
  ///
  /// Internal flow:
  /// 1. Builds an [Answer] with a heuristic [EngagementSignal].
  /// 2. Appends to history and updates the flat [Session.answers] map.
  /// 3. Runs [ConstraintEnforcer.inspectAnswer] — on escalation or stop,
  ///    emits the appropriate event and returns.
  /// 4. Emits the updated [Session].
  /// 5. Invokes [Strategy.nextStep] for the next event.
  Future<void> submitAnswer(dynamic value) async {
    if (_currentStep == null) return;

    final step = _currentStep!;

    // ── Step 1: build Answer with heuristic engagement signal ─────────────
    final heuristicSignal =
        _engagementReader.readHeuristic(
      Answer(
        stepId: step.id,
        stepSpec: step,
        answer: value,
        timestamp: DateTime.now(),
        engagement: EngagementSignal.weak,
      ),
      _session.history,
    );

    final answer = Answer(
      stepId: step.id,
      stepSpec: step,
      answer: value,
      timestamp: DateTime.now(),
      engagement: heuristicSignal,
    );

    // ── Step 2: append to history, update flat answers map ─────────────────
    final updatedHistory = [..._session.history, answer];
    final updatedAnswers = {
      ..._session.answers,
      step.id: value,
    };

    _session = _session.copyWith(
      history: updatedHistory,
      answers: updatedAnswers,
      lastSignal: heuristicSignal,
    );

    // ── Step 3: constraint inspection ──────────────────────────────────────
    final enforcer = ConstraintEnforcer(config.constraints);
    final result = enforcer.inspectAnswer(answer, _session);

    switch (result) {
      case Escalated(:final rule):
        _session = _session.copyWith(status: SessionStatus.escalated);
        final event = EscalationFired(rule: rule);
        _emitEvent(event);
        _emitSession();
        return;
      case Stop(:final reason):
        final event = StreamError(error: reason);
        _emitEvent(event);
        _emitSession();
        return;
      case Allowed():
      case Replaced():
        break;
    }

    // ── Step 4: emit updated session ────────────────────────────────────────
    _emitSession();

    // ── Step 5: run strategy loop ───────────────────────────────────────────
    await _runStrategyLoop();
  }

  /// Pops the last answer from history without calling the LLM.
  ///
  /// This is a v1 simplification — the previously emitted step spec is
  /// restored as [currentStep] exactly as the LLM originally worded it.
  ///
  /// **v2 enhancement:** re-invoke [Strategy.nextStep] from the rewound
  /// [Session] to regenerate a contextually updated question.
  void back() {
    if (_session.history.isEmpty) return;

    final updatedHistory = _session.history.sublist(0, _session.history.length - 1);

    // Rebuild flat answers map from remaining history
    final updatedAnswers = <String, dynamic>{};
    for (final a in updatedHistory) {
      updatedAnswers[a.stepId] = a.answer;
    }
    // Preserve internal keys not tracked in history
    final branchChoices = _session.answers['__branch_choices'];
    if (branchChoices != null) {
      updatedAnswers['__branch_choices'] = branchChoices;
    }

    // Restore the previous step — the step that was just popped was the step
    // the user answered; we need to go back to showing that step again.
    if (_session.history.isNotEmpty) {
      _currentStep = _session.history.last.stepSpec;
    }

    _session = _session.copyWith(
      history: updatedHistory,
      answers: updatedAnswers,
    );

    _emitSession();
  }

  /// Resets the form to its initial state and calls [start] again.
  Future<void> restart() async {
    _currentStep = null;
    await start();
  }

  /// Closes both [StreamController]s.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _sessionsCtrl.close();
    await _eventsCtrl.close();
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  Session _buildInitialSession() {
    final runningContract = Session.composeRunningContract(
      root: config.outcomes,
      currentNode: config.outcomes,
    );
    return Session(
      currentNode: config.outcomes,
      history: const [],
      answers: const {},
      runningContract: runningContract,
      status: SessionStatus.active,
      lastSignal: EngagementSignal.weak,
      reachedOutcome: null,
    );
  }

  /// Runs the [Strategy.nextStep] loop, handling each emitted [StepEvent].
  ///
  /// Collects all events from the strategy and processes them. The loop ends
  /// naturally when the strategy generator completes.
  Future<void> _runStrategyLoop() async {
    if (_disposed) return;
    _isAwaiting = true;

    try {
      // Collect all events from the strategy stream to avoid premature
      // generator cancellation (breaking `await for` early sends a cancel
      // signal that can trigger the generator's catch block).
      final events = await _strategy.nextStep(_session, config).toList();
      for (final event in events) {
        if (_disposed) break;
        _handleStrategyEvent(event);
      }
    } finally {
      _isAwaiting = false;
    }
  }

  void _handleStrategyEvent(StepEvent event) {
    _emitEvent(event);

    switch (event) {
      case StepReady(:final spec):
        _currentStep = spec;
        _emitSession();

      case LayerComplete():
        // Update currentNode if session is currently at a layer that has a next
        final navigator = OutcomeNavigator(config.outcomes);
        final next = navigator.advance(_session);
        if (next != null) {
          final newContract = Session.composeRunningContract(
            root: config.outcomes,
            currentNode: next,
          );
          _session = _session.copyWith(
            currentNode: next,
            runningContract: newContract,
          );
        }
        _emitSession();

      case BranchTaken(:final branchId, :final optionId):
        // Record branch choice in answers['__branch_choices']
        final branchChoices = <String, String>{};
        final existing = _session.answers['__branch_choices'];
        if (existing is Map) {
          for (final entry in existing.entries) {
            branchChoices[entry.key.toString()] = entry.value.toString();
          }
        }
        branchChoices[branchId] = optionId;

        final updatedAnswers = {
          ..._session.answers,
          '__branch_choices': branchChoices,
        };

        // Advance via OutcomeNavigator using the chosen branch option
        final sessionWithChoices =
            _session.copyWith(answers: updatedAnswers);
        final navigator = OutcomeNavigator(config.outcomes);
        final nextNode =
            navigator.advance(sessionWithChoices, chosenBranchOption: optionId);

        if (nextNode != null) {
          final newContract = Session.composeRunningContract(
            root: config.outcomes,
            currentNode: nextNode,
            chosenBranchOptions: branchChoices,
          );
          _session = _session.copyWith(
            currentNode: nextNode,
            answers: updatedAnswers,
            runningContract: newContract,
          );
        } else {
          _session = _session.copyWith(answers: updatedAnswers);
        }
        _emitSession();

      case OutcomeReached(:final outcome):
        _session = _session.copyWith(
          status: SessionStatus.completed,
          reachedOutcome: outcome,
        );
        _emitSession();

      case EscalationFired():
        _session = _session.copyWith(status: SessionStatus.escalated);
        _emitSession();

      case StreamError():
        // Don't update session status — let the form widget show a retry banner.
        // The caller (submitAnswer or start) emits the event; session stays
        // active so the user can retry.
        _emitSession();
    }
  }

  void _emitSession() {
    if (!_disposed) {
      _sessionsCtrl.add(_session);
    }
  }

  void _emitEvent(StepEvent event) {
    if (!_disposed) {
      _eventsCtrl.add(event);
    }
  }
}
