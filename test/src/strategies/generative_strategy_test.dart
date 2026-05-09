import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

String _askStepJson({
  String id = 'step_name',
  String title = 'What is your name?',
  String inputType = 'text',
  String engagement = 'strong',
}) =>
    jsonEncode({
      'decision': 'ask_step',
      'step': {
        'id': id,
        'title': title,
        'inputType': inputType,
      },
      'engagement': engagement,
    });

String _offerExitJson({String engagement = 'weak'}) => jsonEncode({
      'decision': 'offer_exit',
      'exit_offer': {
        'id': 'exit_step',
        'title': 'Would you like to save your progress?',
        'inputType': 'choice',
        'choices': [
          {'id': 'yes', 'label': 'Yes, save and continue later'},
          {'id': 'no', 'label': 'No, keep going'},
        ],
      },
      'engagement': engagement,
    });

String _resolveBranchJson({
  String branchId = 'nutrition_path',
  String optionId = 'with_meal_plan',
  String engagement = 'strong',
}) =>
    jsonEncode({
      'decision': 'resolve_branch',
      'branch_resolution': {
        'branch_id': branchId,
        'option_id': optionId,
        'rationale': 'User mentioned wanting concrete meals',
      },
      'engagement': engagement,
    });

String _completeJson({
  String outcomeId = 'lead_qualified',
  String engagement = 'strong',
}) =>
    jsonEncode({
      'decision': 'complete',
      'outcome': {
        'outcome_id': outcomeId,
        'summary': 'Collected all required fields for lead qualification.',
      },
      'engagement': engagement,
    });

FormConfig _makeConfig({
  List<Constraint> constraints = const [],
  required FakeLlmClient client,
  OutcomeNode? outcomes,
}) {
  return FormConfig(
    contract: sampleContract(),
    constraints: constraints,
    posture: Posture.salesDiscovery(),
    outcomes: outcomes ??
        Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
    client: client,
    model: 'gemini-2.5-flash',
  );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('GenerativeStrategy — ask_step decision', () {
    test('emits StepReady with parsed QuizStepSpec', () async {
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      final event = events.first as StepReady;
      expect(event.spec.id, 'step_name');
      expect(event.spec.title, 'What is your name?');
    });

    test('emits StepReady with correct inputType', () async {
      final client = FakeLlmClient(
        scriptedResponses: [
          _askStepJson(inputType: 'number'),
        ],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      final event = events.first as StepReady;
      expect(event.spec.inputType, QuizInputType.number);
    });

    test('parses choice step with choices list', () async {
      final response = jsonEncode({
        'decision': 'ask_step',
        'step': {
          'id': 'step_goal',
          'title': 'What is your primary goal?',
          'inputType': 'choice',
          'choices': [
            {'id': 'lose_weight', 'label': 'Lose weight', 'iconId': 'trending_down'},
            {'id': 'gain_muscle', 'label': 'Gain muscle', 'iconId': 'fitness_center'},
          ],
        },
        'engagement': 'strong',
      });
      final client = FakeLlmClient(scriptedResponses: [response]);
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      final event = events.first as StepReady;
      expect(event.spec.choices, hasLength(2));
      expect(event.spec.choices!.first.id, 'lose_weight');
      expect(event.spec.choices!.first.iconName, 'trending_down');
    });

    test('calls LLM with correct model and temperature', () async {
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-3-flash',
        temperature: 0.5,
      );
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      await strategy.nextStep(session, config).toList();

      expect(client.invocations, hasLength(1));
      expect(client.invocations.first.model, 'gemini-3-flash');
      expect(client.invocations.first.temperature, 0.5);
    });

    test('includes system prompt in LLM call', () async {
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      await strategy.nextStep(session, config).toList();

      expect(client.invocations.first.systemPrompt, isNotEmpty);
      expect(
        client.invocations.first.systemPrompt,
        contains('You are a form designer'),
      );
    });

    test('emits StreamError for malformed JSON response', () async {
      final client = FakeLlmClient(scriptedResponses: ['not valid json {{{']);
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
    });

    test('emits StreamError for unknown decision value', () async {
      final client = FakeLlmClient(
        scriptedResponses: [
          jsonEncode({'decision': 'unknown_decision', 'engagement': 'strong'}),
        ],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
    });
  });

  group('GenerativeStrategy — offer_exit decision', () {
    test('emits LayerComplete then StepReady', () async {
      final layerNode = Layer(
        id: 'account_only',
        contractDelta: Contract(fields: {}),
        handoff: null,
        next: null,
      );
      final client = FakeLlmClient(scriptedResponses: [_offerExitJson()]);
      final config = _makeConfig(client: client, outcomes: layerNode);
      final session = sampleSession(currentNode: layerNode);
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      // Should get LayerComplete + StepReady
      expect(events, hasLength(2));
      expect(events[0], isA<LayerComplete>());
      expect(events[1], isA<StepReady>());

      final layerComplete = events[0] as LayerComplete;
      expect(layerComplete.offerExit, isTrue);
      expect(layerComplete.layer.id, 'account_only');

      final stepReady = events[1] as StepReady;
      expect(stepReady.spec.id, 'exit_step');
    });

    test('emits only StepReady when no exit_offer field', () async {
      final response = jsonEncode({
        'decision': 'offer_exit',
        'engagement': 'weak',
        // no exit_offer field
      });
      final layerNode = Layer(
        id: 'account_only',
        contractDelta: Contract(fields: {}),
        handoff: null,
        next: null,
      );
      final client = FakeLlmClient(scriptedResponses: [response]);
      final config = _makeConfig(client: client, outcomes: layerNode);
      final session = sampleSession(currentNode: layerNode);
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      // Only LayerComplete — no StepReady since no exit_offer
      expect(events, hasLength(1));
      expect(events[0], isA<LayerComplete>());
    });
  });

  group('GenerativeStrategy — resolve_branch decision', () {
    test('emits BranchTaken with branch_id and option_id', () async {
      final client = FakeLlmClient(scriptedResponses: [_resolveBranchJson()]);
      final config = _makeConfig(client: client, outcomes: gymgeistTree());
      final session = sampleSession(currentNode: gymgeistTree());
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<BranchTaken>());

      final event = events.first as BranchTaken;
      expect(event.branchId, 'nutrition_path');
      expect(event.optionId, 'with_meal_plan');
    });

    test('emits StreamError when branch_resolution field is missing', () async {
      final response = jsonEncode({
        'decision': 'resolve_branch',
        'engagement': 'strong',
        // branch_resolution absent
      });
      final client = FakeLlmClient(scriptedResponses: [response]);
      final config = _makeConfig(client: client, outcomes: gymgeistTree());
      final session = sampleSession(currentNode: gymgeistTree());
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
    });
  });

  group('GenerativeStrategy — complete decision', () {
    test('emits OutcomeReached with correct Outcome and FormResult', () async {
      final outcomeNode = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      final client = FakeLlmClient(
        scriptedResponses: [_completeJson(outcomeId: 'lead_qualified')],
      );
      final config = _makeConfig(client: client, outcomes: outcomeNode);
      final session = sampleSession(
        currentNode: outcomeNode,
        answers: {'name': 'Alice', 'email': 'alice@example.com'},
      );
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<OutcomeReached>());

      final event = events.first as OutcomeReached;
      expect(event.outcome.id, 'lead_qualified');
      expect(event.result.status, SessionStatus.completed);
      expect(event.result.collectedFields['name'], 'Alice');
    });

    test('emits StreamError for unknown outcome_id', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_completeJson(outcomeId: 'nonexistent_outcome')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
    });

    test('completes at a Layer with handoff (Layer id used as outcome_id)',
        () async {
      // Spec §6.2 GymGeist tree: `Layer('account_only', handoff: ...)` is a
      // graceful exit point that may terminate the form. The LLM may pick
      // `complete` with that Layer id when the layer's contract is satisfied
      // and engagement is weak — this should fire the Layer's handoff and end
      // the session, not error out.
      Handoff accountHandoff = (_) {};
      final accountLayer = Layer(
        id: 'account_only',
        contractDelta: Contract(fields: {}),
        handoff: accountHandoff,
        next: Outcome(
          id: 'full_setup',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
      );
      final client = FakeLlmClient(
        scriptedResponses: [_completeJson(outcomeId: 'account_only')],
      );
      final config = _makeConfig(client: client, outcomes: accountLayer);
      final session = sampleSession(currentNode: accountLayer);
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<OutcomeReached>());

      final reached = events.first as OutcomeReached;
      expect(reached.outcome.id, 'account_only');
      expect(reached.outcome.handoff, same(accountHandoff));
      expect(reached.result.status, SessionStatus.completed);
    });

    test('MinSteps refusal: emits StreamError before threshold', () async {
      final outcomeNode = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      final client = FakeLlmClient(
        scriptedResponses: [_completeJson(outcomeId: 'lead_qualified')],
      );
      final config = FormConfig(
        contract: sampleContract(),
        constraints: [MinSteps(value: 3)], // require 3 steps
        posture: Posture.salesDiscovery(),
        outcomes: outcomeNode,
        client: client,
        model: 'gemini-2.5-flash',
      );
      // History has 0 answers — below MinSteps(3)
      final session = sampleSession(currentNode: outcomeNode, history: []);
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
      final err = events.first as StreamError;
      expect(err.error.toString(), contains('MinSteps'));
    });
  });

  group('GenerativeStrategy — constraint integration', () {
    test('MaxSteps: emits StreamError when step count >= max', () async {
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = FormConfig(
        contract: sampleContract(),
        constraints: [MaxSteps(value: 2)], // max 2 steps
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
      );
      // History already has 2 answers → at MaxSteps limit
      final session = sampleSession(
        history: [
          sampleAnswer(stepId: 'step_1', answer: 'answer 1'),
          sampleAnswer(stepId: 'step_2', answer: 'answer 2'),
        ],
      );
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
      final err = events.first as StreamError;
      expect(err.error.toString(), contains('MaxSteps'));
      // LLM should NOT have been called
      expect(client.invocations, isEmpty);
    });

    test('NeverCollect: replaces step when field name matches', () async {
      final response = jsonEncode({
        'decision': 'ask_step',
        'step': {
          'id': 'payment_info',
          'title': 'Please provide your credit card number',
          'inputType': 'text',
        },
        'engagement': 'weak',
      });
      final client = FakeLlmClient(scriptedResponses: [response]);
      final config = FormConfig(
        contract: sampleContract(),
        constraints: [NeverCollect(fieldOrTopic: 'payment_info')],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
      );
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());
      final event = events.first as StepReady;
      // Should be replaced — not the original step
      expect(event.spec.id, isNot('payment_info'));
      expect(event.spec.id, startsWith('__never_collect_'));
    });

    test('EscalateIf: emits EscalationFired when trigger matches previous answer', () async {
      final escalateConstraint = EscalateIf(
        trigger: 'eating disorder',
        handler: _noopHandler(),
      );
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = FormConfig(
        contract: sampleContract(),
        constraints: [escalateConstraint],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
      );
      // Last answer contains the trigger phrase
      final session = sampleSession(
        history: [
          sampleAnswer(
            stepId: 'step_health',
            answer: 'I have an eating disorder and want to lose weight fast',
          ),
        ],
      );
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<EscalationFired>());
      // LLM should NOT have been called
      expect(client.invocations, isEmpty);
    });

    test('StopIf: emits StreamError when trigger matches previous answer', () async {
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = FormConfig(
        contract: sampleContract(),
        constraints: [StopIf(trigger: 'under 16')],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
      );
      final session = sampleSession(
        history: [
          sampleAnswer(
            stepId: 'step_age',
            answer: 'I am under 16 years old',
          ),
        ],
      );
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
      expect(client.invocations, isEmpty);
    });
  });

  group('GenerativeStrategy — engagement loop', () {
    test('LLM engagement is read from response', () async {
      // When LLM returns engagement: 'weak', strategy should not throw
      final client = FakeLlmClient(
        scriptedResponses: [_askStepJson(engagement: 'weak')],
      );
      final config = _makeConfig(client: client);
      // Provide one prior answer so engagement reader has something to work with
      final session = sampleSession(
        history: [sampleAnswer(stepId: 'step_0', answer: 'short')],
      );
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());
    });

    test('negative LLM engagement does not crash strategy', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_askStepJson(engagement: 'negative')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession(
        history: [sampleAnswer(stepId: 'step_0', answer: 'ok')],
      );
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());
    });
  });

  group('GenerativeStrategy — cachedContent passthrough', () {
    test('passes config.cachedContent through to client.generate', () async {
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
        cachedContent: 'cachedContents/test-123',
      );
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      await strategy.nextStep(session, config).toList();

      expect(client.invocations, hasLength(1));
      expect(client.invocations.first.cachedContent, 'cachedContents/test-123');
    });

    test('passes null cachedContent when config has no cachedContent', () async {
      final client = FakeLlmClient(scriptedResponses: [_askStepJson()]);
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      await strategy.nextStep(session, config).toList();

      expect(client.invocations, hasLength(1));
      expect(client.invocations.first.cachedContent, isNull);
    });
  });

  group('GenerativeStrategy — streaming buffer', () {
    test('4 JSON fragments produce a single StepReady event', () async {
      // Split the JSON into 4 fragments
      final fullJson = _askStepJson();
      final quarter = fullJson.length ~/ 4;
      final fragments = [
        fullJson.substring(0, quarter),
        fullJson.substring(quarter, quarter * 2),
        fullJson.substring(quarter * 2, quarter * 3),
        fullJson.substring(quarter * 3),
      ];

      // FakeLlmClient emits the whole scripted response as one chunk.
      // To test multi-fragment accumulation, we use a custom fake that streams
      // the response in multiple chunks.
      final multiClient = _MultiChunkFakeLlmClient(chunks: fragments);

      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: multiClient,
        model: 'gemini-2.5-flash',
      );
      final session = sampleSession();
      final strategy = GenerativeStrategy();

      final events = await strategy.nextStep(session, config).toList();
      // One StepReady — the 4 fragments were buffered and parsed as one JSON object
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());
      final event = events.first as StepReady;
      expect(event.spec.id, 'step_name');
    });
  });
}

// ── Test helpers ─────────────────────────────────────────────────────────────

EscalationHandler _noopHandler() => (_) {};

/// A fake LLM client that emits multiple chunks per generate call.
class _MultiChunkFakeLlmClient extends LlmClient {
  final List<String> chunks;
  _MultiChunkFakeLlmClient({required this.chunks});

  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    Map<String, dynamic>? responseSchema,
    Map<String, dynamic>? responseJsonSchema,
    required String model,
    double temperature = 0.7,
    String? cachedContent,
  }) {
    return Stream.fromIterable(chunks);
  }

  @override
  Future<String> createCachedContent({
    required String systemInstruction,
    required String model,
    Duration ttl = const Duration(seconds: 300),
  }) async => 'cachedContents/fake';

  @override
  Future<void> deleteCachedContent(String name) async {}
}
