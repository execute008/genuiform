import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';
import 'package:mocktail/mocktail.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockOnComplete extends Mock {
  void call(FormResult result);
}

class _MockOnEscalation extends Mock {
  void call(EscalateIf rule);
}

class _MockOnError extends Mock {
  void call(Object error);
}

// Fallback values for mocktail
class _FakeFormResult extends Fake implements FormResult {}
class _FakeEscalateIf extends Fake implements EscalateIf {}

// ── JSON helpers ──────────────────────────────────────────────────────────────

String _askStepJson({
  String id = 'step_1',
  String title = 'What is your name?',
  String inputType = 'text',
  String engagement = 'strong',
}) =>
    jsonEncode({
      'decision': 'ask_step',
      'step': {'id': id, 'title': title, 'inputType': inputType},
      'engagement': engagement,
    });

String _completeJson({String outcomeId = 'lead_qualified'}) => jsonEncode({
      'decision': 'complete',
      'outcome': {
        'outcome_id': outcomeId,
        'summary': 'Done.',
      },
      'engagement': 'strong',
    });

// ── Widget factory ────────────────────────────────────────────────────────────

Widget _buildForm({
  required FakeLlmClient client,
  OutcomeNode? outcomes,
  List<Constraint> constraints = const [],
  void Function(FormResult)? onComplete,
  void Function(EscalateIf)? onEscalation,
  void Function(Object)? onError,
  Strategy? strategy,
}) {
  final outcome = outcomes ??
      Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );

  return MaterialApp(
    home: Scaffold(
      body: GenuiForm(
        contract: Contract(fields: {
          'name': const FieldSpec(type: 'String', required: true),
        }),
        constraints: constraints,
        posture: Posture.salesDiscovery(),
        outcomes: outcome,
        client: client,
        model: 'gemini-2.5-flash',
        strategy: strategy,
        onComplete: onComplete,
        onEscalation: onEscalation,
        onError: onError,
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFormResult());
    registerFallbackValue(_FakeEscalateIf());
  });
  group('GenuiForm — happy path', () {
    testWidgets('shows first step question after start', (tester) async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'What is your name?'),
      ]);

      await tester.pumpWidget(_buildForm(client: client));
      await tester.pumpAndSettle();

      expect(find.text('What is your name?'), findsOneWidget);
    });

    testWidgets('shows streaming indicator while awaiting', (tester) async {
      // Use a response with a delay so we can catch the indicator
      final client = FakeLlmClient(
        scriptedResponses: [
          _askStepJson(id: 'step_1', title: 'First question?'),
        ],
        responseDelay: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(_buildForm(client: client));
      // Immediately after pump, the form starts awaiting
      await tester.pump(const Duration(milliseconds: 50));

      // StreamingIndicator should be visible during the await
      expect(find.byType(LinearProgressIndicator), findsWidgets);

      // Drain the pending timer before the test ends
      await tester.pumpAndSettle();
    });

    testWidgets('shows progress bar', (tester) async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'Question 1?'),
      ]);

      await tester.pumpWidget(_buildForm(client: client));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows Next button when step is displayed', (tester) async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'What is your name?'),
      ]);

      await tester.pumpWidget(_buildForm(client: client));
      await tester.pumpAndSettle();

      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('tapping Next advances to next step', (tester) async {
      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'First question?'),
        _askStepJson(id: 'step_2', title: 'Second question?'),
      ]);

      await tester.pumpWidget(_buildForm(client: client));
      await tester.pumpAndSettle();

      expect(find.text('First question?'), findsOneWidget);

      // Enter text so Next is actionable
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Second question?'), findsOneWidget);
    });

    testWidgets('onComplete called when OutcomeReached', (tester) async {
      final onComplete = _MockOnComplete();
      when(() => onComplete.call(any())).thenReturn(null);

      final outcome = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );

      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'Name?'),
        _completeJson(outcomeId: 'lead_qualified'),
      ]);

      await tester.pumpWidget(_buildForm(
        client: client,
        outcomes: outcome,
        onComplete: onComplete.call,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      verify(() => onComplete.call(any())).called(1);
    });

    testWidgets('result panel shown when form completes', (tester) async {
      final outcome = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );

      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'Name?'),
        _completeJson(outcomeId: 'lead_qualified'),
      ]);

      await tester.pumpWidget(_buildForm(
        client: client,
        outcomes: outcome,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // The result panel should be visible
      expect(find.text('lead_qualified'), findsOneWidget);
    });

    testWidgets('Restart button in result panel resets form', (tester) async {
      final outcome = Outcome(
        id: 'lead_qualified',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );

      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'First run question?'),
        _completeJson(outcomeId: 'lead_qualified'),
        _askStepJson(id: 'step_1', title: 'First run question?'),
      ]);

      await tester.pumpWidget(_buildForm(
        client: client,
        outcomes: outcome,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should see result panel with Restart
      expect(find.text('Restart'), findsOneWidget);

      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();

      // Form should be back to a step
      expect(find.text('First run question?'), findsOneWidget);
    });
  });

  group('GenuiForm — escalation', () {
    testWidgets('onEscalation called and escalation panel shown',
        (tester) async {
      final onEscalation = _MockOnEscalation();
      when(() => onEscalation.call(any())).thenReturn(null);

      final client = FakeLlmClient(scriptedResponses: [
        _askStepJson(id: 'step_1', title: 'Tell us about yourself?'),
        // strategy won't be called again — escalation fires from answer check
      ]);

      await tester.pumpWidget(_buildForm(
        client: client,
        constraints: [
          EscalateIf(trigger: 'hostile'),
        ],
        onEscalation: onEscalation.call,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'I am feeling very hostile today');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      verify(() => onEscalation.call(any())).called(1);
      // Escalation panel should be shown
      expect(find.textContaining("we'll take it from here"), findsOneWidget);
    });
  });

  group('GenuiForm — error handling', () {
    testWidgets('onError called on StreamError event', (tester) async {
      final onError = _MockOnError();
      when(() => onError.call(any())).thenReturn(null);

      // Empty script → FakeLlmClient throws StateError → GenerativeStrategy
      // catches it and emits StreamError
      final client = FakeLlmClient(scriptedResponses: [
        '{"decision":"ask_step","step":{"id":"s1","title":"Q?","inputType":"text"},"engagement":"weak"}',
        '{"not_valid_json_for_decision": true}', // malformed → StreamError
      ]);

      await tester.pumpWidget(_buildForm(
        client: client,
        onError: onError.call,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      verify(() => onError.call(any())).called(1);
    });

    testWidgets('error banner shown with Retry button on StreamError',
        (tester) async {
      final client = FakeLlmClient(scriptedResponses: [
        '{"decision":"ask_step","step":{"id":"s1","title":"Q1?","inputType":"text"},"engagement":"weak"}',
        '{"invalid": true}', // will produce unknown decision → StreamError
        '{"decision":"ask_step","step":{"id":"s2","title":"Q2?","inputType":"text"},"engagement":"weak"}',
      ]);

      await tester.pumpWidget(_buildForm(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'answer');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Error banner with Retry should be visible
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
