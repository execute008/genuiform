// Pure Dart — no Flutter imports.

import 'dart:convert';

import '../models/message.dart';
import '../models/quiz_step_spec.dart';
import '../models/session.dart';
import '../models/step_event.dart';
import '../runtime/constraint_enforcer.dart';
import '../runtime/engagement_reader.dart';
import 'form_config.dart';
import 'prompt_builder.dart';
import 'strategy.dart';

/// The guided strategy — the LLM picks the next step from a developer-supplied
/// catalog of [QuizStepSpec] definitions.
///
/// Unlike [GenerativeStrategy], the LLM does not generate the step JSON.
/// Instead it returns a single `next_step_id` string that is looked up in
/// [FormConfig.guidedCatalog]. This drastically reduces LLM workload and
/// produces more predictable latency (~200–400ms vs ~1.5–2.5s).
///
/// ### Pre-conditions
///
/// [FormConfig.guidedCatalog] must be non-null when [nextStep] is called.
/// Passing a null catalog is a programming error — an [ArgumentError] is thrown
/// immediately (not as a [StreamError]).
class GuidedStrategy extends Strategy {
  GuidedStrategy({EngagementReader? engagementReader})
      : _engagementReader = engagementReader ?? EngagementReader();

  final EngagementReader _engagementReader;

  @override
  Stream<StepEvent> nextStep(Session session, FormConfig config) {
    final catalog = config.guidedCatalog;
    if (catalog == null) {
      throw ArgumentError(
        'GuidedStrategy requires FormConfig.guidedCatalog to be non-null. '
        'Supply a List<QuizStepSpec> catalog when constructing FormConfig.',
      );
    }
    return _nextStepWithCatalog(session, config, catalog);
  }

  Stream<StepEvent> _nextStepWithCatalog(
    Session session,
    FormConfig config,
    List<QuizStepSpec> catalog,
  ) async* {
    try {
      final enforcer = ConstraintEnforcer(config.constraints);

      // ── Inspect previous answer for escalation ────────────────────────────
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
            break;
        }
      }

      // ── Build shorter guided system prompt ────────────────────────────────
      final systemPrompt = buildGuidedSystemPrompt(config, session);

      // ── Build guided response schema ──────────────────────────────────────
      final catalogIds = catalog.map((s) => s.id).toList();
      final responseSchema = _buildGuidedSchema(catalogIds);

      // ── Build messages ────────────────────────────────────────────────────
      final messages = _buildMessages(session);

      // ── Call LLM and buffer ───────────────────────────────────────────────
      final buffer = StringBuffer();
      await for (final chunk in config.client.generate(
        systemPrompt: systemPrompt,
        messages: messages,
        responseSchema: responseSchema,
        model: config.model,
        temperature: config.temperature,
      )) {
        buffer.write(chunk);
      }

      // ── Parse response ────────────────────────────────────────────────────
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(buffer.toString()) as Map<String, dynamic>;
      } catch (e) {
        yield StreamError(error: 'Failed to parse guided LLM response JSON: $e');
        return;
      }

      final nextStepId = json['next_step_id'] as String?;
      final engagementStr = json['engagement'] as String?;

      // Update engagement reading (informational — controller owns Session)
      if (session.history.isNotEmpty) {
        final llmSignal = _engagementReader.readFromLlm(engagementStr);
        final heuristicSignal = _engagementReader.readHeuristic(
          session.history.last,
          session.history.sublist(0, session.history.length - 1),
        );
        _engagementReader.combine(llmSignal, heuristicSignal);
      }

      if (nextStepId == null) {
        yield const StreamError(error: 'Guided LLM response missing "next_step_id"');
        return;
      }

      // ── Look up step in catalog ───────────────────────────────────────────
      final matched = catalog.where((s) => s.id == nextStepId).firstOrNull;
      if (matched == null) {
        yield StreamError(
          error: 'GuidedStrategy: LLM returned unknown step id "$nextStepId". '
              'Known ids: ${catalogIds.join(', ')}',
        );
        return;
      }

      // ── Constraint check on the matched step ──────────────────────────────
      final stepResult = enforcer.check(matched, session);
      switch (stepResult) {
        case Replaced(:final replacement):
          yield StepReady(spec: replacement);
        case Stop(:final reason):
          yield StreamError(error: reason);
          return;
        case Allowed():
          yield StepReady(spec: matched);
        case Escalated():
          yield StepReady(spec: matched);
      }
    } catch (e) {
      yield StreamError(error: e);
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Map<String, dynamic> _buildGuidedSchema(List<String> catalogIds) => {
        'type': 'object',
        'required': ['next_step_id', 'engagement'],
        'properties': {
          'next_step_id': {
            'type': 'string',
            'enum': catalogIds,
          },
          'engagement': {
            'type': 'string',
            'enum': ['strong', 'weak', 'negative'],
          },
        },
      };

  List<Message> _buildMessages(Session session) {
    final messages = <Message>[];
    for (final answer in session.history) {
      messages.add(Message(
        role: MessageRole.assistant,
        content: answer.stepSpec.title,
      ));
      messages.add(Message(
        role: MessageRole.user,
        content: answer.answer?.toString() ?? '',
      ));
    }
    return messages;
  }
}
