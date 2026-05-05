import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../../_fixtures/sessions.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('AnswerHistorySidebar — rendering', () {
    testWidgets('shows "No answers yet" for empty history', (tester) async {
      await tester.pumpWidget(
        _wrap(const AnswerHistorySidebar(history: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No answers yet.'), findsOneWidget);
    });

    testWidgets('renders step title for each answer', (tester) async {
      final history = [
        sampleAnswer(
          stepId: 'name',
          answer: 'Alice',
          engagement: EngagementSignal.strong,
        ),
        sampleAnswer(
          stepId: 'test_step',
          answer: 'idk',
          engagement: EngagementSignal.weak,
        ),
        sampleAnswer(
          stepId: 'test_step',
          answer: 'stop this',
          engagement: EngagementSignal.negative,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 400,
            child: AnswerHistorySidebar(history: history),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step titles come from sampleAnswer → sampleStep → title: 'Test question'
      expect(find.text('Test question'), findsWidgets);
    });

    testWidgets('all three answers are visible in a short list', (tester) async {
      final history = [
        sampleAnswer(
          stepId: 'step_1',
          answer: 'Alice',
          engagement: EngagementSignal.strong,
        ),
        sampleAnswer(
          stepId: 'step_2',
          answer: 'idk',
          engagement: EngagementSignal.weak,
        ),
        sampleAnswer(
          stepId: 'step_3',
          answer: 'I want to stop',
          engagement: EngagementSignal.negative,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 600,
            child: AnswerHistorySidebar(history: history),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Row indices 1, 2, 3 should be present
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
    });

    testWidgets('engagement badges are colour-coded', (tester) async {
      final history = [
        sampleAnswer(
          stepId: 'step_1',
          answer: 'detailed answer',
          engagement: EngagementSignal.strong,
        ),
        sampleAnswer(
          stepId: 'step_2',
          answer: 'idk',
          engagement: EngagementSignal.weak,
        ),
        sampleAnswer(
          stepId: 'step_3',
          answer: 'leave me alone',
          engagement: EngagementSignal.negative,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 600,
            child: AnswerHistorySidebar(history: history),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge labels confirm all three engagement signals are rendered
      expect(find.text('strong'), findsOneWidget);
      expect(find.text('weak'), findsOneWidget);
      expect(find.text('neg'), findsOneWidget);

      // Verify colour containers exist for badges
      final containers = tester.widgetList<Container>(find.byType(Container));
      final greenBadge = containers.any((c) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          return d.border != null &&
              (d.border! as Border).top.color == Colors.green;
        }
        return false;
      });
      final redBadge = containers.any((c) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          return d.border != null &&
              (d.border! as Border).top.color == Colors.red;
        }
        return false;
      });
      final amberBadge = containers.any((c) {
        final d = c.decoration;
        if (d is BoxDecoration) {
          return d.border != null &&
              (d.border! as Border).top.color == Colors.amber;
        }
        return false;
      });

      expect(greenBadge, isTrue, reason: 'strong badge should be green');
      expect(amberBadge, isTrue, reason: 'weak badge should be amber');
      expect(redBadge, isTrue, reason: 'negative badge should be red');
    });

    testWidgets('displays answer value text', (tester) async {
      final history = [
        sampleAnswer(
          stepId: 'step_1',
          answer: 'My answer value',
          engagement: EngagementSignal.strong,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 200,
            child: AnswerHistorySidebar(history: history),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My answer value'), findsOneWidget);
    });
  });
}
