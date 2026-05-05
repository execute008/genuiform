import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

// ── JSON helpers ───────────────────────────────────────────────────────────────

String _askStepJson({
  String id = 'step_1',
  String title = 'What is your goal?',
  String inputType = 'text',
  String engagement = 'strong',
}) =>
    jsonEncode({
      'decision': 'ask_step',
      'step': {'id': id, 'title': title, 'inputType': inputType},
      'engagement': engagement,
    });

String _completeJson({String outcomeId = 'done'}) => jsonEncode({
      'decision': 'complete',
      'outcome': {'outcome_id': outcomeId, 'summary': 'Complete.'},
      'engagement': 'strong',
    });

// ── Test widget factory ────────────────────────────────────────────────────────

Widget _buildSplitDemo({
  required FakeLlmClient leftClient,
  required FakeLlmClient rightClient,
}) {
  final outcomes = Outcome(
    id: 'done',
    contractDelta: Contract(fields: {}),
    handoff: null,
  );

  return MaterialApp(
    home: Scaffold(
      body: SplitUserDemo(
        contract: Contract(fields: {
          'name': const FieldSpec(type: 'String', required: true),
        }),
        constraints: const [],
        posture: Posture.salesDiscovery(),
        outcomes: outcomes,
        leftClient: leftClient,
        rightClient: rightClient,
        model: 'gemini-2.5-flash',
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SplitUserDemo — structure', () {
    testWidgets('renders exactly two GenuiForm instances', (tester) async {
      final leftClient = FakeLlmClient(
        scriptedResponses: [_askStepJson(title: 'Left question?')],
      );
      final rightClient = FakeLlmClient(
        scriptedResponses: [_askStepJson(title: 'Right question?')],
      );

      await tester.pumpWidget(_buildSplitDemo(
        leftClient: leftClient,
        rightClient: rightClient,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GenuiForm), findsNWidgets(2));
    });

    testWidgets('shows column header labels', (tester) async {
      final leftClient = FakeLlmClient(
        scriptedResponses: [_askStepJson()],
      );
      final rightClient = FakeLlmClient(
        scriptedResponses: [_askStepJson()],
      );

      await tester.pumpWidget(_buildSplitDemo(
        leftClient: leftClient,
        rightClient: rightClient,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Engaged user'), findsOneWidget);
      expect(find.text('Tired user'), findsOneWidget);
    });

    testWidgets('left and right forms render independently', (tester) async {
      final leftClient = FakeLlmClient(
        scriptedResponses: [
          _askStepJson(id: 'left_q', title: 'Left-only question?'),
        ],
      );
      final rightClient = FakeLlmClient(
        scriptedResponses: [
          _askStepJson(id: 'right_q', title: 'Right-only question?'),
        ],
      );

      await tester.pumpWidget(_buildSplitDemo(
        leftClient: leftClient,
        rightClient: rightClient,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Left-only question?'), findsOneWidget);
      expect(find.text('Right-only question?'), findsOneWidget);
    });

    testWidgets('both forms advance independently on Next tap', (tester) async {
      final leftClient = FakeLlmClient(
        scriptedResponses: [
          _askStepJson(id: 'l1', title: 'Left Q1?'),
          _completeJson(outcomeId: 'done'),
        ],
      );
      final rightClient = FakeLlmClient(
        scriptedResponses: [
          _askStepJson(id: 'r1', title: 'Right Q1?'),
        ],
      );

      await tester.pumpWidget(_buildSplitDemo(
        leftClient: leftClient,
        rightClient: rightClient,
      ));
      await tester.pumpAndSettle();

      // Both initial questions visible
      expect(find.text('Left Q1?'), findsOneWidget);
      expect(find.text('Right Q1?'), findsOneWidget);

      // Tap Next on the left form only (first TextField in left half)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Alice');
      final nextButtons = find.text('Next');
      await tester.tap(nextButtons.first);
      await tester.pumpAndSettle();

      // Left form has completed; right form still shows its question
      expect(find.text('done'), findsOneWidget);
      expect(find.text('Right Q1?'), findsOneWidget);
    });

    testWidgets('renders with a Row at the top level', (tester) async {
      final leftClient = FakeLlmClient(
        scriptedResponses: [_askStepJson()],
      );
      final rightClient = FakeLlmClient(
        scriptedResponses: [_askStepJson()],
      );

      await tester.pumpWidget(_buildSplitDemo(
        leftClient: leftClient,
        rightClient: rightClient,
      ));
      await tester.pumpAndSettle();

      // The top-level layout of SplitUserDemo is a Row
      expect(find.byType(Row), findsWidgets);
    });
  });
}
