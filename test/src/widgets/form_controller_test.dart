import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../_fixtures/sessions.dart';

// ── JSON helpers ──────────────────────────────────────────────────────────────

String _askStepJson({
  String id = 'step_1',
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

String _completeJson({
  String outcomeId = 'lead_qualified',
  String engagement = 'strong',
}) =>
    jsonEncode({
      'decision': 'complete',
      'outcome': {
        'outcome_id': outcomeId,
        'summary': 'All required fields collected.',
      },
      'engagement': engagement,
    });

String _escalateJson() => jsonEncode({
      'decision': 'ask_step',
      'step': {
        'id': 'step_hostile',
        'title': 'Anything else?',
        'inputType': 'text',
      },
      'engagement': 'negative',
    });

// ── Config factory ────────────────────────────────────────────────────────────

FormConfig _makeConfig({
  required FakeLlmClient client,
  List<Constraint> constraints = const [],
  OutcomeNode? outcomes,
}) =>
    FormConfig(
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('FormController — happy path', () {
    test('start() emits first session and currentStep becomes non-null',
        () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'What is your name?'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      await controller.start();

      expect(controller.currentStep, isNotNull);
      expect(controller.currentStep!.id, 'step_1');
      await controller.dispose();
    });

    test('sessions stream emits after start()', () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      final sessions = <Session>[];
      controller.sessions.listen(sessions.add);

      await controller.start();

      expect(sessions, isNotEmpty);
      await controller.dispose();
    });

    test('submitAnswer() advances to next step and emits updated session',
        () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'First question?'),
        _askStepJson(id: 'step_2', title: 'Second question?'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      final sessions = <Session>[];
      controller.sessions.listen(sessions.add);

      await controller.start();
      await controller.submitAnswer('Alice');

      // After submitting, session history should have one entry
      expect(controller.currentSession.history, hasLength(1));
      expect(controller.currentStep?.id, 'step_2');
      await controller.dispose();
    });

    test('StepReady → StepReady → OutcomeReached completes the form',
        () async {
      final outcome = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
        _askStepJson(id: 'step_2'),
        _completeJson(outcomeId: 'lead_qualified'),
      ]);
      final config = _makeConfig(client: client, outcomes: outcome);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      StepEvent? lastEvent;
      controller.events.listen((e) => lastEvent = e);

      await controller.start();            // → step_1
      await Future.microtask(() {});       // flush pending event deliveries
      await controller.submitAnswer('A'); // → step_2
      await Future.microtask(() {});
      await controller.submitAnswer('B'); // → OutcomeReached
      await Future.microtask(() {});       // ensure events are delivered

      expect(controller.currentSession.status, SessionStatus.completed);
      expect(lastEvent, isA<OutcomeReached>());
      await controller.dispose();
    });
  });

  group('FormController — back()', () {
    test('back() with empty history is a no-op', () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      await controller.start();
      expect(controller.currentSession.history, isEmpty);

      // Should not throw
      controller.back();
      expect(controller.currentSession.history, isEmpty);
      await controller.dispose();
    });

    test('back() pops the last answer from history', () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
        _askStepJson(id: 'step_2'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      await controller.start();
      await controller.submitAnswer('Answer 1');
      expect(controller.currentSession.history, hasLength(1));

      controller.back();
      expect(controller.currentSession.history, isEmpty);
      await controller.dispose();
    });

    test('back() rebuilds answers map from remaining history', () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
        _askStepJson(id: 'step_2'),
        _askStepJson(id: 'step_3'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      await controller.start();
      await controller.submitAnswer('Answer A');
      await controller.submitAnswer('Answer B');

      expect(controller.currentSession.history, hasLength(2));
      controller.back();
      expect(controller.currentSession.history, hasLength(1));
      // step_2's answer (Answer B) should be removed
      expect(controller.currentSession.answers['step_2'], isNull);
      await controller.dispose();
    });
  });

  group('FormController — restart()', () {
    test('restart() resets session to initial state', () async {
      final outcome = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'), // first start()
        _askStepJson(id: 'step_2'),
        _completeJson(outcomeId: 'lead_qualified'), // complete form
        _askStepJson(id: 'step_1'), // after restart()
      ]);
      final config = _makeConfig(client: client, outcomes: outcome);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      await controller.start();
      await controller.submitAnswer('A');
      await controller.submitAnswer('B');

      expect(controller.currentSession.status, SessionStatus.completed);

      await controller.restart();

      expect(controller.currentSession.status, SessionStatus.active);
      expect(controller.currentSession.history, isEmpty);
      await controller.dispose();
    });
  });

  group('FormController — escalation', () {
    test('EscalateIf trigger → EscalationFired event and status escalated',
        () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'Tell us about yourself?'),
        // The second call won't be reached because escalation fires in the
        // FormController after inspecting the answer (not via strategy)
        _escalateJson(),
      ]);
      final config = _makeConfig(
        client: client,
        constraints: [
          EscalateIf(trigger: 'hostile'),
        ],
      );
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      final events = <StepEvent>[];
      controller.events.listen(events.add);

      await controller.start();
      await Future.microtask(() {}); // flush event deliveries
      // Answer that triggers the escalation constraint
      await controller.submitAnswer('I am feeling very hostile today');
      await Future.microtask(() {}); // ensure EscalationFired is delivered

      expect(
        events.any((e) => e is EscalationFired),
        isTrue,
        reason: 'Expected EscalationFired event',
      );
      expect(controller.currentSession.status, SessionStatus.escalated);
      await controller.dispose();
    });
  });

  group('FormController — isAwaiting', () {
    test('isAwaiting is false before start()', () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      expect(controller.isAwaiting, isFalse);
      await controller.dispose();
    });

    test('isAwaiting is false after start() resolves', () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      await controller.start();
      expect(controller.isAwaiting, isFalse);
      await controller.dispose();
    });
  });

  group('FormController — dispose()', () {
    test('dispose() closes streams without throwing', () async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1'),
      ]);
      final config = _makeConfig(client: client);
      final controller = FormController(
        config: config,
        strategy: GenerativeStrategy(),
      );

      await controller.start();
      await controller.dispose();
      // Disposing twice should not throw
      await controller.dispose();
    });
  });
}
