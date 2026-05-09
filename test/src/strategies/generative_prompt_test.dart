import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

void main() {
  // ── buildStaticSystemPrompt ───────────────────────────────────────────────

  group('buildStaticSystemPrompt', () {
    late FormConfig config;

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
    });

    test('contains opening role statement verbatim', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(
        prompt,
        contains(
          'You are a form designer running an adaptive intake conversation.',
        ),
      );
    });

    test('contains YOUR JOB EACH TURN section', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('YOUR JOB EACH TURN:'));
      expect(prompt, contains('a) Ask the next question (emit a step)'));
      expect(prompt, contains('b) Offer a graceful exit'));
      expect(prompt, contains('c) Resolve a Branch'));
      expect(prompt, contains('d) Mark the form complete'));
    });

    test('contains BASE CONTRACT section header', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(
        prompt,
        contains('BASE CONTRACT (collected for completion; deltas added per path):'),
      );
    });

    test('does NOT contain old CONTRACT header', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(
        prompt,
        isNot(contains(
          'CONTRACT (running, including current path through outcome tree):',
        )),
      );
    });

    test('contains field names from config.contract', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('name'));
      expect(prompt, contains('email'));
    });

    test('contains field descriptions in contract section', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('Full name of the contact'));
    });

    test('contains required/optional labels in contract section', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('required'));
    });

    test('contains CONSTRAINTS section header', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(
        prompt,
        contains('CONSTRAINTS (hard rules — never violate):'),
      );
    });

    test('contains constraint values', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('payment_info'));
      expect(prompt, contains('MaxSteps(8)'));
    });

    test('contains POSTURE section header', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('POSTURE:'));
    });

    test('contains posture knobs with numeric values', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('persistence: 4/5'));
      expect(prompt, contains('pacing: 3/5'));
    });

    test('contains posture voice', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(
        prompt,
        contains('Sovereign, curious, never desperate. Senior consultant tone.'),
      );
    });

    test('contains OUTCOME TREE section header', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('OUTCOME TREE:'));
    });

    test('does NOT contain current node marker <<< in static prompt', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, isNot(contains('<<<')));
    });

    test('does NOT contain CONVERSATION SO FAR section', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, isNot(contains('CONVERSATION SO FAR:')));
    });

    test('does NOT contain ENGAGEMENT SIGNAL FROM LAST ANSWER section', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, isNot(contains('ENGAGEMENT SIGNAL FROM LAST ANSWER:')));
    });

    test('contains INSTRUCTIONS section', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('INSTRUCTIONS:'));
      expect(prompt, contains('Ask ONE focused question per step. Never bundle.'));
      expect(prompt, contains('Never invent input types.'));
    });

    test('contains icon registry in INSTRUCTIONS section', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(prompt, contains('Use icons from:'));
      expect(prompt, contains('fitness_center'));
      expect(prompt, contains('restaurant'));
    });

    test('ends with JSON instruction', () {
      final prompt = buildStaticSystemPrompt(config);
      expect(
        prompt,
        contains('Return ONLY valid JSON matching the schema. No prose, no markdown.'),
      );
    });

    test('renders Layer and Branch nodes in tree without <<< marker', () {
      final configWithTree = FormConfig(
        contract: sampleContract(),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: gymgeistTree(),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
      );
      final prompt = buildStaticSystemPrompt(configWithTree);
      expect(prompt, contains('Layer[account_only]'));
      expect(prompt, contains('Layer[with_workout_plan]'));
      expect(prompt, contains('Branch[nutrition_path]'));
      expect(prompt, isNot(contains('<<<')));
    });

    // ── Golden string snapshot ───────────────────────────────────────────────

    test('golden string: structure matches new section ordering', () {
      final prompt = buildStaticSystemPrompt(config);

      // Sections in order: preamble, YOUR JOB, BASE CONTRACT, CONSTRAINTS,
      // POSTURE, OUTCOME TREE, INSTRUCTIONS, JSON-only directive.
      final sectionHeaders = [
        'You are a form designer running an adaptive intake conversation.',
        'YOUR JOB EACH TURN:',
        'BASE CONTRACT (collected for completion; deltas added per path):',
        'CONSTRAINTS (hard rules — never violate):',
        'POSTURE:',
        'OUTCOME TREE:',
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
              'Prompt wording has drifted from spec.',
        );
        cursor = idx + header.length;
      }
    });

    // ── Byte-stability assertion (load-bearing for caching) ──────────────────

    test('byte-identical across sessions with different histories and currentNode positions', () {
      final promptA = buildStaticSystemPrompt(config);

      // Different session: has history, different currentNode
      final differentSession = Session(
        currentNode: Outcome(
          id: 'other_node',
          contractDelta: Contract(fields: {'extra': const FieldSpec(type: 'String', required: false)}),
          handoff: null,
        ),
        history: [
          Answer(
            stepId: 'q1',
            stepSpec: sampleStep(id: 'q1', title: 'Name?'),
            answer: 'Bob',
            timestamp: DateTime(2026, 1, 1),
            engagement: EngagementSignal.strong,
          ),
        ],
        answers: {'q1': 'Bob'},
        runningContract: Contract(fields: {
          'name': const FieldSpec(type: 'String', required: true),
          'email': const FieldSpec(type: 'String', required: true),
          'extra': const FieldSpec(type: 'String', required: false),
        }),
        status: SessionStatus.active,
        lastSignal: EngagementSignal.strong,
      );

      // buildStaticSystemPrompt takes only config — session is irrelevant
      final promptB = buildStaticSystemPrompt(config);

      expect(
        promptA,
        equals(promptB),
        reason: 'Static prompt must be byte-identical across sessions of the '
            'same config — this is the load-bearing assertion for caching.',
      );
    });
  });

  // ── buildDynamicTurnContext ──────────────────────────────────────────────

  group('buildDynamicTurnContext', () {
    late FormConfig config;

    setUp(() {
      config = FormConfig(
        contract: Contract(fields: {
          'name': const FieldSpec(type: 'String', required: true),
          'email': const FieldSpec(type: 'String', required: true),
        }),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: Outcome(
          id: 'lead_qualified',
          contractDelta: Contract(fields: {}),
          handoff: null,
        ),
        client: FakeLlmClient(scriptedResponses: []),
        model: 'gemini-2.5-flash',
      );
    });

    test('contains [CONTEXT] header', () {
      final session = sampleSession();
      final ctx = buildDynamicTurnContext(config, session);
      expect(ctx, contains('[CONTEXT]'));
    });

    test('contains current_node id', () {
      final node = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      final session = sampleSession(currentNode: node);
      final ctx = buildDynamicTurnContext(config, session);
      expect(ctx, contains('current_node: lead_qualified'));
    });

    test('contains <<< marker via current_node id, not via static prompt', () {
      // The current node is identified by id in [CONTEXT], not via <<< in the tree.
      final node = Outcome(
        id: 'my_node',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      final session = sampleSession(currentNode: node);
      final ctx = buildDynamicTurnContext(config, session);
      expect(ctx, contains('current_node: my_node'));
    });

    test('shows (none) for contract_delta when runningContract == base contract', () {
      final session = Session(
        currentNode: Outcome(id: 'lead_qualified', contractDelta: Contract(fields: {}), handoff: null),
        history: [],
        answers: {},
        runningContract: config.contract, // same as base
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      final ctx = buildDynamicTurnContext(config, session);
      expect(ctx, contains('contract_delta: (none)'));
    });

    test('shows delta fields when runningContract has extra fields', () {
      final session = Session(
        currentNode: Outcome(id: 'lead_qualified', contractDelta: Contract(fields: {}), handoff: null),
        history: [],
        answers: {},
        runningContract: Contract(fields: {
          'name': const FieldSpec(type: 'String', required: true),
          'email': const FieldSpec(type: 'String', required: true),
          'goals': const FieldSpec(type: 'List', required: true), // delta
        }),
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
      final ctx = buildDynamicTurnContext(config, session);
      expect(ctx, contains('goals'));
      expect(ctx, isNot(contains('(none)')));
    });

    test('contains last_engagement value', () {
      final session = Session(
        currentNode: Outcome(id: 'lead_qualified', contractDelta: Contract(fields: {}), handoff: null),
        history: [],
        answers: {},
        runningContract: config.contract,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.strong,
      );
      final ctx = buildDynamicTurnContext(config, session);
      expect(ctx, contains('last_engagement: strong'));
    });
  });

  // ── buildGenerativeSystemPrompt (deprecated wrapper) ─────────────────────

  group('buildGenerativeSystemPrompt (deprecated wrapper)', () {
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
      session = Session(
        currentNode: outcomeNode,
        history: [],
        answers: {},
        runningContract: config.contract,
        status: SessionStatus.active,
        lastSignal: EngagementSignal.weak,
      );
    });

    test('returns same content as buildStaticSystemPrompt', () {
      // ignore: deprecated_member_use
      final legacy = buildGenerativeSystemPrompt(config, session);
      final modern = buildStaticSystemPrompt(config);
      expect(legacy, equals(modern));
    });

    test('contains opening role statement', () {
      // ignore: deprecated_member_use
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(
        prompt,
        contains('You are a form designer running an adaptive intake conversation.'),
      );
    });

    test('does NOT contain CONVERSATION SO FAR', () {
      // ignore: deprecated_member_use
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, isNot(contains('CONVERSATION SO FAR:')));
    });

    test('does NOT contain <<< marker', () {
      // ignore: deprecated_member_use
      final prompt = buildGenerativeSystemPrompt(config, session);
      expect(prompt, isNot(contains('<<<')));
    });
  });

  // ── buildGuidedSystemPrompt ───────────────────────────────────────────────

  group('buildGuidedSystemPrompt', () {
    test('is significantly shorter than static generative prompt', () {
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
      final staticPrompt = buildStaticSystemPrompt(config);

      expect(
        guidedPrompt.length,
        lessThan(1500),
        reason:
            'Guided system prompt is ${guidedPrompt.length} chars — must be '
            '< 1500 chars per acceptance criteria.',
      );
      expect(guidedPrompt.length, lessThan(staticPrompt.length));
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
