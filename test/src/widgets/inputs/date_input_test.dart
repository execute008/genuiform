import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/widgets/inputs/date_input.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _dateSpec({String? firstDate, String? lastDate}) => QuizStepSpec(
      id: 'date_q',
      title: 'Pick a date',
      inputType: QuizInputType.date,
      configuration: {
        'firstDate': firstDate,
        'lastDate': lastDate,
      }..removeWhere((_, v) => v == null),
    );

void main() {
  group('DateInput', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('shows "Pick a date" when no date is selected', (tester) async {
      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Pick a date'), findsOneWidget);
    });

    testWidgets('shows formatted date when value is set', (tester) async {
      final date = DateTime(2025, 6, 15);
      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(),
          value: date,
          onChanged: (_) {},
        ),
      ));
      // Format: DD/MM/YYYY
      expect(find.text('15/06/2025'), findsOneWidget);
    });

    testWidgets('tapping button opens date picker', (tester) async {
      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(
            firstDate: '2000-01-01',
            lastDate: '2030-12-31',
          ),
          value: null,
          onChanged: (_) {},
        ),
      ));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      // The date picker dialog should be visible
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('picking a date fires onChanged with the selected DateTime',
        (tester) async {
      dynamic emitted;

      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(
            firstDate: '2020-01-01',
            lastDate: '2030-12-31',
          ),
          value: DateTime(2025, 6, 1),
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      // Tap a day (15) in the calendar — it's always present in June 2025
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      // Tap OK to confirm the selection
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(emitted, isA<DateTime>());
      expect((emitted as DateTime).day, equals(15));
    });

    testWidgets('shows validation message when set', (tester) async {
      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(),
          value: null,
          onChanged: (_) {},
          validationMessage: 'Please pick a date',
        ),
      ));
      expect(find.text('Please pick a date'), findsOneWidget);
    });

    testWidgets('does not show validation message when null', (tester) async {
      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Please pick a date'), findsNothing);
    });

    testWidgets('calendar icon is rendered in the button', (tester) async {
      await tester.pumpWidget(_wrap(
        DateInput(
          spec: _dateSpec(),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });
  });
}
