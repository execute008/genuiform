import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

String _guidedResponse({
  String stepId = 'step_name',
  String engagement = 'strong',
}) =>
    jsonEncode({
      'next_step_id': stepId,
      'engagement': engagement,
    });

List<QuizStepSpec> _catalog() => [
      sampleStep(id: 'step_name', title: 'What is your name?'),
      sampleStep(id: 'step_email', title: 'What is your email?'),
      sampleStep(id: 'step_goal', title: 'What is your primary goal?'),
    ];

FormConfig _makeConfig({
  List<Constraint> constraints = const [],
  required FakeLlmClient client,
  List<QuizStepSpec>? catalog,
}) {
  return FormConfig(
    contract: sampleContract(),
    constraints: constraints,
    posture: Posture.supportiveOnboarding(),
    outcomes: Outcome(
      id: 'onboarding_complete',
      contractDelta: Contract(fields: {}),
      handoff: null,
    ),
    client: client,
    model: 'gemini-2.5-flash',
    guidedCatalog: catalog ?? _catalog(),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('GuidedStrategy — happy path', () {
    test('emits StepReady matching catalog entry', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_name')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());

      final event = events.first as StepReady;
      expect(event.spec.id, 'step_name');
      expect(event.spec.title, 'What is your name?');
    });

    test('picks second catalog entry correctly', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_email')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      final event = events.first as StepReady;
      expect(event.spec.id, 'step_email');
      expect(event.spec.title, 'What is your email?');
    });

    test('picks third catalog entry correctly', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_goal')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      final event = events.first as StepReady;
      expect(event.spec.id, 'step_goal');
    });

    test('calls LLM with shorter guided system prompt', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_name')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      await strategy.nextStep(session, config).toList();

      expect(client.invocations, hasLength(1));
      final prompt = client.invocations.first.systemPrompt;
      expect(prompt.length, lessThan(1500));
    });

    test('system prompt contains catalog IDs and titles', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_name')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      await strategy.nextStep(session, config).toList();

      final prompt = client.invocations.first.systemPrompt;
      expect(prompt, contains('step_name'));
      expect(prompt, contains('step_email'));
      expect(prompt, contains('step_goal'));
    });

    test('uses smaller guided response schema', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_name')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      await strategy.nextStep(session, config).toList();

      final schema = client.invocations.first.responseSchema;
      final props = schema['properties'] as Map<String, dynamic>;
      expect(props.containsKey('next_step_id'), isTrue);
      expect(props.containsKey('engagement'), isTrue);
      // Should not contain generative-specific keys
      expect(props.containsKey('decision'), isFalse);
    });

    test('response schema enum contains catalog ids', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_name')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      await strategy.nextStep(session, config).toList();

      final schema = client.invocations.first.responseSchema;
      final props = schema['properties'] as Map<String, dynamic>;
      final nextStepProp = props['next_step_id'] as Map<String, dynamic>;
      final enumValues = nextStepProp['enum'] as List<dynamic>;
      expect(enumValues, containsAll(['step_name', 'step_email', 'step_goal']));
    });
  });

  group('GuidedStrategy — error cases', () {
    test('throws ArgumentError when guidedCatalog is null', () {
      final client = FakeLlmClient(scriptedResponses: []);
      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'onboarding_complete',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
        guidedCatalog: null, // null — programming error
      );
      final session = sampleSession();
      final strategy = GuidedStrategy();

      // ArgumentError is thrown synchronously before any yield
      expect(
        () => strategy.nextStep(session, config),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('emits StreamError for unknown step id from LLM', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_nonexistent')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
      final err = events.first as StreamError;
      expect(err.error.toString(), contains('step_nonexistent'));
    });

    test('emits StreamError for malformed JSON response', () async {
      final client = FakeLlmClient(scriptedResponses: ['not json {{{']);
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
    });

    test('emits StreamError when next_step_id is missing from response', () async {
      final client = FakeLlmClient(
        scriptedResponses: [jsonEncode({'engagement': 'strong'})],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession();
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StreamError>());
    });
  });

  group('GuidedStrategy — constraint integration', () {
    test('NeverCollect replaces matched catalog step', () async {
      final blockedStep = sampleStep(
        id: 'payment_info',
        title: 'Enter your credit card',
      );
      final catalog = [
        blockedStep,
        sampleStep(id: 'step_name', title: 'What is your name?'),
      ];
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'payment_info')],
      );
      final config = FormConfig(
        contract: sampleContract(),
        constraints: [NeverCollect(fieldOrTopic: 'payment_info')],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'onboarding_complete',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
        guidedCatalog: catalog,
      );
      final session = sampleSession();
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());
      final event = events.first as StepReady;
      // Should be replaced
      expect(event.spec.id, startsWith('__never_collect_'));
    });

    test('EscalateIf: emits EscalationFired when previous answer matches trigger', () async {
      final escalateConstraint = EscalateIf(
        trigger: 'eating disorder',
        handler: _noopHandler(),
      );
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_name')],
      );
      final config = FormConfig(
        contract: sampleContract(),
        constraints: [escalateConstraint],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'onboarding_complete',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: client,
        model: 'gemini-2.5-flash',
        guidedCatalog: _catalog(),
      );
      final session = sampleSession(
        history: [
          sampleAnswer(
            stepId: 'step_health',
            answer: 'I have had an eating disorder for years',
          ),
        ],
      );
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<EscalationFired>());
      // LLM should NOT have been called
      expect(client.invocations, isEmpty);
    });
  });

  group('GuidedStrategy — engagement', () {
    test('no crash when previous answer engagement is weak', () async {
      final client = FakeLlmClient(
        scriptedResponses: [_guidedResponse(stepId: 'step_name', engagement: 'weak')],
      );
      final config = _makeConfig(client: client);
      final session = sampleSession(
        history: [sampleAnswer(stepId: 'step_0', answer: 'ok')],
      );
      final strategy = GuidedStrategy();

      final events = await strategy.nextStep(session, config).toList();
      expect(events, hasLength(1));
      expect(events.first, isA<StepReady>());
    });
  });

  group('buildGuidedSystemPrompt — character count assertion', () {
    test('prompt is < 1500 chars for a 3-step catalog', () {
      final config = _makeConfig(
        client: FakeLlmClient(scriptedResponses: []),
        catalog: _catalog(),
      );
      final session = sampleSession();
      final prompt = buildGuidedSystemPrompt(config, session);
      expect(
        prompt.length,
        lessThan(1500),
        reason:
            'Guided system prompt must be < 1500 chars. '
            'Current length: ${prompt.length}',
      );
    });
  });
}

EscalationHandler _noopHandler() => (_) {};
