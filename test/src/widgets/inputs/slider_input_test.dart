import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/widgets/inputs/slider_input.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _sliderSpec({
  num min = 0,
  num max = 100,
  num step = 1,
  String? unit,
  dynamic initialValue,
}) =>
    QuizStepSpec(
      id: 'slider_q',
      title: 'How much?',
      inputType: QuizInputType.slider,
      initialValue: initialValue,
      configuration: <String, dynamic>{
        'min': min,
        'max': max,
        'step': step,
        'unit': unit,
      }..removeWhere((_, v) => v == null),
    );

void main() {
  group('SliderInput', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(),
          value: 50.0,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('displays current value with unit', (tester) async {
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(min: 0, max: 200, unit: 'kg'),
          value: 70,
          onChanged: (_) {},
        ),
      ));
      expect(find.textContaining('70'), findsWidgets);
      expect(find.textContaining('kg'), findsOneWidget);
    });

    testWidgets('defaults to min when value is null', (tester) async {
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(min: 10, max: 100),
          value: null,
          onChanged: (_) {},
        ),
      ));
      // Should render with the min value (10) displayed
      expect(find.textContaining('10'), findsWidgets);
    });

    testWidgets('uses spec.initialValue when value is null', (tester) async {
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(min: 0, max: 100, initialValue: 42.0),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.textContaining('42'), findsWidgets);
    });

    testWidgets('onChanged emits value when slider changes', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(min: 0, max: 100, step: 1),
          value: 50.0,
          onChanged: (v) => emitted = v,
        ),
      ));

      // Drag the slider to the right
      final sliderFinder = find.byType(Slider);
      final sliderRenderObject = tester.renderObject(sliderFinder);
      final size = sliderRenderObject.paintBounds.size;

      await tester.drag(sliderFinder, Offset(size.width * 0.1, 0));
      await tester.pump();

      // After drag, onChanged should have been called
      expect(emitted, isNotNull);
      expect(emitted, isA<num>());
    });

    testWidgets('shows validation message when set', (tester) async {
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(),
          value: 50.0,
          onChanged: (_) {},
          validationMessage: 'Required field',
        ),
      ));
      expect(find.text('Required field'), findsOneWidget);
    });

    testWidgets('does not show validation message when null', (tester) async {
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(),
          value: 50.0,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Required field'), findsNothing);
    });

    testWidgets('snaps to step — integer step produces integer-like values',
        (tester) async {
      final emittedValues = <dynamic>[];
      await tester.pumpWidget(_wrap(
        SliderInput(
          spec: _sliderSpec(min: 0, max: 10, step: 1),
          value: 5.0,
          onChanged: emittedValues.add,
        ),
      ));

      final sliderFinder = find.byType(Slider);
      await tester.drag(sliderFinder, const Offset(20, 0));
      await tester.pump();

      // All emitted values should be whole numbers (modulo floating-point)
      for (final v in emittedValues) {
        final d = (v as num).toDouble();
        expect(d % 1.0, closeTo(0.0, 0.01),
            reason: 'Expected integer-like value, got $v');
      }
    });
  });
}
