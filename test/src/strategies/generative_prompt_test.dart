import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

void main() {
  group('buildGenerativeSystemPrompt', () {
    // A small, deterministic config for golden tests.
    late FormConfig config;
    late Session session;

    setUp(() {
      config = FormConfig(
        contract: Contract(fields: {
          'name': const FieldSpec(
            type: 'String',
            required: true,
            description: 'Full name of the contact',
          ),
          'email': const FieldSpec(
            type: 'String',
            required: true,
          ),
        }),
        constraints: [
          NeverCollect(fieldOrTopic: 'payment_info'),
          MaxSteps(value: 8),
        ],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
      );

      final outcomeNode = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      // Session's runningContract must include the fields we want to test.
      // In production, the OutcomeNavigator computes this; in tests we set it
      // directly.
      session = Session(
        currentNode: outcomeNode,
        history: [],
        answers: {},
        runningContract: config.contract,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
    });

    // ── Section presence tests ──────────────────────────────────────────────

    test('contains opening role statement verbatim', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(
        prompt,
        contains(
          'You are a form designer running an adaptive intake conversation.',
        ),
      );
    });

    test('contains YOUR JOB EACH TURN section', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('YOUR JOB EACH TURN:'));
      expect(prompt, contains('a) Ask the next question (emit a step)'));
      expect(prompt, contains('b) Offer a graceful exit'));
      expect(prompt, contains('c) Resolve a Branch'));
      expect(prompt, contains('d) Mark the form complete'));
    });

    test('contains CONTRACT section header', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(
        prompt,
        contains('CONTRACT (running, including current path through outcome tree):'),
      );
    });

    test('contains field names from contract', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('name'));
      expect(prompt, contains('email'));
    });

    test('contains field descriptions in contract section', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('Full name of the contact'));
    });

    test('contains required/optional labels in contract section', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('required'));
    });

    test('contains CONSTRAINTS section header', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(
        prompt,
        contains('CONSTRAINTS (hard rules — never violate):'),
      );
    });

    test('contains constraint values', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('payment_info'));
      expect(prompt, contains('MaxSteps(8)'));
    });

    test('contains POSTURE section header', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('POSTURE:'));
    });

    test('contains posture knobs with numeric values', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      // salesDiscovery has persistence: 4, pacing: 3
      expect(prompt, contains('persistence: 4/5'));
      expect(prompt, contains('pacing: 3/5'));
    });

    test('contains posture voice', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(
        prompt,
        contains('Sovereign, curious, never desperate. Senior consultant tone.'),
      );
    });

    test('contains OUTCOME TREE section header', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(
        prompt,
        contains('OUTCOME TREE (current position highlighted):'),
      );
    });

    test('contains current node marker in tree', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      // The current node should be marked with <<<
      expect(prompt, contains('<<<'));
    });

    test('contains CONVERSATION SO FAR section header', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('CONVERSATION SO FAR:'));
    });

    test('shows (no answers yet) when history is empty', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('(no answers yet)'));
    });

    test('contains ENGAGEMENT SIGNAL FROM LAST ANSWER section', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('ENGAGEMENT SIGNAL FROM LAST ANSWER:'));
    });

    test('contains current engagement signal value', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      // default session has lastSignal: weak
      expect(prompt, contains('weak'));
    });

    test('contains INSTRUCTIONS section', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, contains('INSTRUCTIONS:'));
      expect(prompt, contains('Ask ONE focused question per step. Never bundle.'));
      expect(prompt, contains("Never invent input types."));
    });

    test('contains icon registry in INSTRUCTIONS section', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      // The icon registry list should be injected into the instructions line
      expect(prompt, contains('Use icons from:'));
      // Some known icon names should appear
      expect(prompt, contains('fitness_center'));
      expect(prompt, contains('restaurant'));
    });

    test('ends with JSON instruction', () {
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(
        prompt,
        contains('Return ONLY valid JSON matching the schema. No prose, no markdown.'),
      );
    });

    // ── History rendering ─────────────────────────────────────────────────

    test('renders history as Q: / A: pairs', () {
      final step = sampleStep(id: 'q_name', title: 'What is your name?');
      final answer = Answer(
        stepId: 'q_name',
        stepSpec: step,
        answer: 'Alice Smith',
        timestamp: DateTime(2026, 5, 5, 12),
        engagement: EngagementSignal.strong,
      );
      final s = sampleSession(
        currentNode: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        history: [answer],
      );
      final prompt = buildGenerativeSystemPrompt(config, s);
      expect(prompt, contains('Q: What is your name?'));
      expect(prompt, contains('A: Alice Smith'));
    });

    // ── Layer + branch tree rendering ──────────────────────────────────────

    test('renders Layer and Branch nodes in tree', () {
      final configWithTree = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
      );
      final s = sampleSession(currentNode: gymgeistTree());
      final prompt = buildGenerativeSystemPrompt(configWithTree, s);
      expect(prompt, contains('Layer[account_only]'));
      expect(prompt, contains('Layer[with_workout_plan]'));
      expect(prompt, contains('Branch[nutrition_path]'));
      // current node marker
      expect(prompt, contains('<<<'));
    });

    // ── Golden string snapshot ─────────────────────────────────────────────

    test('golden string: structure matches §10.1 verbatim headers', () {
      final prompt = buildGenerativeSystemPrompt(config, session);

      // The golden test — if this fails, the diff should be reviewed before
      // accepting the change. The spec §10.1 template sections are checked in
      // order. This is the load-bearing assertion for prompt drift detection.
      final sectionHeaders = [
        'You are a form designer running an adaptive intake conversation.',
        'YOUR JOB EACH TURN:',
        'CONTRACT (running, including current path through outcome tree):',
        'CONSTRAINTS (hard rules — never violate):',
        'POSTURE:',
        'OUTCOME TREE (current position highlighted):',
        'CONVERSATION SO FAR:',
        'ENGAGEMENT SIGNAL FROM LAST ANSWER:',
        'INSTRUCTIONS:',
        'Return ONLY valid JSON matching the schema. No prose, no markdown.',
      ];

      var cursor = 0;
      for (final header in sectionHeaders) {
        final idx = prompt.indexOf(header, cursor);
        expect(
          idx,
          greaterThanOrEqualTo(cursor),
          reason:
              'Section "$header" not found after position $cursor. '
              'Prompt wording has drifted from spec §10.1.',
        );
        cursor = idx + header.length;
      }
    });
  });

  // ── buildGuidedSystemPrompt ───────────────────────────────────────────────

  group('buildGuidedSystemPrompt', () {
    test('is significantly shorter than generative prompt', () {
      final catalog = [
        sampleStep(id: 'step_name', title: 'What is your name?'),
        sampleStep(id: 'step_email', title: 'What is your email?'),
        sampleStep(id: 'step_goal', title: 'What is your goal?'),
      ];
      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
        guidedCatalog: catalog,
      );
      final session = sampleSession();

      final guidedPrompt = buildGuidedSystemPrompt(config, session);
      final generativePrompt = buildGenerativeSystemPrompt(config, session);

      // Guided must be < 1500 chars (acceptance criterion from spec)
      expect(
        guidedPrompt.length,
        lessThan(1500),
        reason:
            'Guided system prompt is ${guidedPrompt.length} chars — must be '
            '< 1500 chars per acceptance criteria.',
      );
      // Guided must be shorter than generative
      expect(guidedPrompt.length, lessThan(generativePrompt.length));
    });

    test('contains catalog ids and titles', () {
      final catalog = [
        sampleStep(id: 'step_name', title: 'What is your name?'),
        sampleStep(id: 'step_email', title: 'What is your email?'),
      ];
      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
        guidedCatalog: catalog,
      );
      final session = sampleSession();
      final prompt = buildGuidedSystemPrompt(config, session);

      expect(prompt, contains('step_name'));
      expect(prompt, contains('What is your name?'));
      expect(prompt, contains('step_email'));
      expect(prompt, contains('What is your email?'));
    });

    test('contains pick-next-step instruction', () {
      final config = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
        guidedCatalog: [sampleStep()],
      );
      final session = sampleSession();
      final prompt = buildGuidedSystemPrompt(config, session);

      expect(prompt, contains('next_step_id'));
    });
  });
}
