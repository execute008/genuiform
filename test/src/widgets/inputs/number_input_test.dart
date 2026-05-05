import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/widgets/inputs/number_input.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _numberSpec({
  num? min,
  num? max,
  bool allowDecimal = false,
}) =>
    QuizStepSpec(
      id: 'number_q',
      title: 'Enter number',
      inputType: QuizInputType.number,
      configuration: <String, dynamic>{
        'min': min,
        'max': max,
        'allowDecimal': allowDecimal,
      }..removeWhere((_, v) => v == null),
    );

void main() {
  group('NumberInput', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('typing 42 emits int 42 when allowDecimal is false',
        (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(allowDecimal: false),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '42');
      await tester.pump();

      expect(emitted, equals(42));
      expect(emitted, isA<int>());
    });

    testWidgets('typing 3.14 emits double when allowDecimal is true',
        (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(allowDecimal: true),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '3.14');
      await tester.pump();

      expect(emitted, isA<double>());
      expect(emitted as double, closeTo(3.14, 0.001));
    });

    testWidgets('emits value even when below min', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(min: 10, max: 100),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();

      expect(emitted, isNotNull);
      expect(emitted, equals(5));
    });

    testWidgets('shows inline range error when below min', (tester) async {
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(min: 10, max: 100),
          value: null,
          onChanged: (_) {},
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '5');
      await tester.pump();

      expect(find.textContaining('Minimum'), findsOneWidget);
    });

    testWidgets('shows inline range error when above max', (tester) async {
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(min: 0, max: 100),
          value: null,
          onChanged: (_) {},
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '150');
      await tester.pump();

      expect(find.textContaining('Maximum'), findsOneWidget);
    });

    testWidgets('no range error for valid value', (tester) async {
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(min: 0, max: 100),
          value: null,
          onChanged: (_) {},
        ),
      ));

      await tester.enterText(find.byType(TextFormField), '50');
      await tester.pump();

      expect(find.textContaining('Minimum'), findsNothing);
      expect(find.textContaining('Maximum'), findsNothing);
    });

    testWidgets('shows validation message when set', (tester) async {
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(),
          value: null,
          onChanged: (_) {},
          validationMessage: 'Required',
        ),
      ));
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('initialises with existing value', (tester) async {
      await tester.pumpWidget(_wrap(
        NumberInput(
          spec: _numberSpec(),
          value: 77,
          onChanged: (_) {},
        ),
      ));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, equals('77'));
    });
  });
}
