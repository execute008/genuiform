// Pure Dart — no Flutter imports.

import 'dart:convert';

import '../llm/schemas.dart';
import '../models/answer.dart';
import '../models/form_result.dart';
import '../models/message.dart';
import '../models/outcomes.dart';
import '../models/quiz_choice.dart';
import '../models/quiz_input_type.dart';
import '../models/quiz_step_spec.dart';
import '../models/session.dart';
import '../models/session_status.dart';
import '../models/step_event.dart';
import '../runtime/constraint_enforcer.dart';
import '../runtime/engagement_reader.dart';
import 'form_config.dart';
import 'prompt_builder.dart';
import 'strategy.dart';

/// The generative strategy — every step emitted by the LLM, schema-constrained.
///
/// On each call to [nextStep]:
/// 1. Inspects the previous answer (if any) for escalation triggers.
/// 2. Enforces [MaxSteps] before calling the LLM.
/// 3. Builds the §10.1 system prompt via [buildGenerativeSystemPrompt].
/// 4. Calls [FormConfig.client.generate] and buffers the stream into a single
///    JSON string (spec §15 — no partial JSON parsing).
/// 5. Parses the `decision` discriminator and emits the corresponding
///    [StepEvent].
/// 6. Reads `engagement` from every response and combines it with the
///    heuristic backend via [EngagementReader.combine].
///
/// All errors are surfaced as [StreamError] events — the stream never throws.
class GenerativeStrategy extends Strategy {
  GenerativeStrategy({EngagementReader? engagementReader})
      : _engagementReader = engagementReader ?? EngagementReader();

  final EngagementReader _engagementReader;

  @override
  Stream<StepEvent> nextStep(Session session, FormConfig config) async* {
    try {
      final enforcer = ConstraintEnforcer(config.constraints);

      // ── Step 1: inspect previous answer for escalation ────────────────────
      if (session.history.isNotEmpty) {
        final lastAnswer = session.history.last;
        final answerResult = enforcer.inspectAnswer(lastAnswer, session);
        switch (answerResult) {
          case Escalated(:final rule):
            yield EscalationFired(rule: rule);
            return;
          case Stop(:final reason):
            yield StreamError(error: reason);
            return;
          case Allowed():
          case Replaced():
            // continue
            break;
        }
      }

      // ── Step 1b: enforce MaxSteps before LLM call ─────────────────────────
      final maxStepsResult = enforcer.check(
        QuizStepSpec(
          id: '__max_steps_probe',
          title: '',
          inputType: QuizInputType.noneJustInformation,
        ),
        session,
      );
      if (maxStepsResult case Stop(:final reason)) {
        yield StreamError(error: reason);
        return;
      }

      // ── Step 2: build system prompt ───────────────────────────────────────
      final systemPrompt = buildStaticSystemPrompt(config);

      // ── Step 3: call LLM and buffer the stream ────────────────────────────
      final messages = _buildMessages(config, session);
      final responseSchema = generativeStrategyResponseSchema();

      final buffer = StringBuffer();
      await for (final chunk in config.client.generate(
        systemPrompt: systemPrompt,
        messages: messages,
        responseSchema: responseSchema,
        model: config.model,
        temperature: config.temperature,
        cachedContent: config.cachedContent,
      )) {
        buffer.write(chunk);
      }

      // ── Step 4: parse JSON and dispatch on decision ───────────────────────
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      } catch (e) {
        yield StreamError(error: 'Failed to parse LLM response JSON: $e');
        return;
      }

      final decision = json['decision'] as String?;
      final engagementStr = json['engagement'] as String?;

      // Compute combined engagement signal (LLM + heuristic).
      // The result is informational for the caller — the controller updates
      // Session.lastSignal. The strategy itself stays stateless.
      if (session.history.isNotEmpty) {
        final llmSignal = _engagementReader.readFromLlm(engagementStr);
        final heuristicSignal = _engagementReader.readHeuristic(
          session.history.last,
          session.history.sublist(0, session.history.length - 1),
        );
        // The combined signal would normally go to the controller via a
        // dedicated event; for v1 it is embedded in the StepEvent where
        // relevant (OutcomeReached.result carries the session state).
        _engagementReader.combine(llmSignal, heuristicSignal);
      }

      switch (decision) {
        // ── ask_step ─────────────────────────────────────────────────────────
        case 'ask_step':
          final stepJson = json['step'] as Map<String, dynamic>?;
          if (stepJson == null) {
            yield const StreamError(error: 'ask_step decision missing "step" field');
            return;
          }
          QuizStepSpec spec;
          try {
            spec = _parseStepSpec(stepJson);
          } catch (e) {
            yield StreamError(error: 'Failed to parse step spec: $e');
            return;
          }

          // Check + possibly replace via ConstraintEnforcer
          final stepResult = enforcer.check(spec, session);
          switch (stepResult) {
            case Replaced(:final replacement):
              yield StepReady(spec: replacement);
            case Stop(:final reason):
              yield StreamError(error: reason);
              return;
            case Allowed():
              yield StepReady(spec: spec);
            case Escalated():
              // Escalated is not returned from check() — only inspectAnswer()
              yield StepReady(spec: spec);
          }

        // ── offer_exit ────────────────────────────────────────────────────────
        case 'offer_exit':
          final exitJson = json['exit_offer'] as Map<String, dynamic>?;

          // Find the current Layer in the tree (walk to find nearest Layer)
          final currentLayer = _findCurrentLayer(session.currentNode, config.outcomes);
          if (currentLayer != null) {
            yield LayerComplete(layer: currentLayer, offerExit: true);
          }

          if (exitJson != null) {
            QuizStepSpec exitSpec;
            try {
              exitSpec = _parseStepSpec(exitJson);
            } catch (e) {
              yield StreamError(error: 'Failed to parse exit_offer spec: $e');
              return;
            }
            yield StepReady(spec: exitSpec);
          }

        // ── resolve_branch ────────────────────────────────────────────────────
        case 'resolve_branch':
          final branchRes = json['branch_resolution'] as Map<String, dynamic>?;
          if (branchRes == null) {
            yield const StreamError(
              error: 'resolve_branch decision missing "branch_resolution" field',
            );
            return;
          }
          final branchId = branchRes['branch_id'] as String?;
          final optionId = branchRes['option_id'] as String?;
          if (branchId == null || optionId == null) {
            yield const StreamError(
              error: 'branch_resolution missing branch_id or option_id',
            );
            return;
          }
          yield BranchTaken(branchId: branchId, optionId: optionId);

        // ── complete ──────────────────────────────────────────────────────────
        case 'complete':
          // MinSteps check — refuse premature completion
          if (!enforcer.isAboveMinimum(session)) {
            yield const StreamError(
              error: 'MinSteps constraint: too few steps to complete',
            );
            return;
          }

          final outcomeData = json['outcome'] as Map<String, dynamic>?;
          final outcomeId = outcomeData?['outcome_id'] as String?;
          // summary is available in outcomeData['summary'] for downstream use
          // once FormResult gains a summary field in v0.4.

          // Find the matching Outcome node in the tree
          final outcomeNode = _findOutcome(config.outcomes, outcomeId);
          if (outcomeNode == null) {
            yield StreamError(
              error: 'complete decision referenced unknown outcome_id: $outcomeId',
            );
            return;
          }

          final result = FormResult(
            collectedFields: Map<String, dynamic>.from(session.answers),
            reachedOutcome: outcomeNode,
            history: List<Answer>.from(session.history),
            status: SessionStatus.completed,
          );

          yield OutcomeReached(outcome: outcomeNode, result: result);

        default:
          yield StreamError(
            error: 'Unknown decision value from LLM: $decision',
          );
      }
    } catch (e) {
      yield StreamError(error: e);
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  List<Message> _buildMessages(FormConfig config, Session session) {
    final dynamicContext = buildDynamicTurnContext(config, session);
    final messages = <Message>[];

    if (session.history.isEmpty) {
      // No prior turns — synthesize a single user message carrying only the
      // dynamic context block.
      messages.add(Message(
        role: MessageRole.user,
        content: dynamicContext,
      ));
      return messages;
    }

    for (var i = 0; i < session.history.length; i++) {
      final answer = session.history[i];
      // Assistant asked the question
      messages.add(Message(
        role: MessageRole.assistant,
        content: answer.stepSpec.title,
      ));
      // User gave an answer; append dynamic context to the last user turn.
      final userContent = answer.answer?.toString() ?? '';
      final isLast = i == session.history.length - 1;
      messages.add(Message(
        role: MessageRole.user,
        content: isLast ? '$userContent\n\n$dynamicContext' : userContent,
      ));
    }
    return messages;
  }

  QuizStepSpec _parseStepSpec(Map<String, dynamic> json) {
    final inputTypeStr = json['inputType'] as String;
    final inputType = quizInputTypeFromJson(inputTypeStr);

    List<QuizChoice>? choices;
    final choicesJson = json['choices'] as List<dynamic>?;
    if (choicesJson != null) {
      choices = choicesJson.map((c) {
        final choiceMap = c as Map<String, dynamic>;
        return QuizChoice(
          id: choiceMap['id'] as String,
          label: choiceMap['label'] as String,
          iconName: choiceMap['iconId'] as String?,
        );
      }).toList();
    }

    // Build configuration for slider fields
    Map<String, dynamic>? configuration;
    final min = json['min'];
    final max = json['max'];
    final step = json['step'];
    final unit = json['unit'];
    if (min != null || max != null || step != null || unit != null) {
      configuration = {
        'min': ?min,
        'max': ?max,
        'step': ?step,
        'unit': ?unit,
      };
    }

    return QuizStepSpec(
      id: json['id'] as String,
      title: json['title'] as String,
      inputType: inputType,
      description: json['description'] as String?,
      choices: choices,
      configuration: configuration,
    );
  }

  /// Finds the [Layer] node matching [session.currentNode] if currentNode is
  /// a Layer, or returns null.
  Layer? _findCurrentLayer(OutcomeNode current, OutcomeNode root) {
    if (current is Layer) return current;
    // Walk all descendants to find a Layer with matching id
    for (final node in root.descendants()) {
      if (node is Layer && node.id == current.id) return node;
    }
    return null;
  }

  /// Finds the terminal node for `complete`'s `outcome_id`.
  ///
  /// Matches an [Outcome] first; if none exists, accepts a [Layer] (graceful
  /// exit point per spec §6.2) by promoting it to a synthetic [Outcome] that
  /// carries the Layer's id, contractDelta, and handoff.
  Outcome? _findOutcome(OutcomeNode root, String? id) {
    if (id == null) return null;
    Layer? layerMatch;
    for (final node in root.descendants()) {
      if (node is Outcome && node.id == id) return node;
      if (node is Layer && node.id == id) layerMatch = node;
    }
    if (layerMatch != null) {
      return Outcome(
        id: layerMatch.id,
        contractDelta: layerMatch.contractDelta,
        handoff: layerMatch.handoff,
      );
    }
    return null;
  }
}

