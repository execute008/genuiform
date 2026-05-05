import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _spec(QuizInputType type, {List<QuizChoice>? choices}) =>
    QuizStepSpec(
      id: 'test_step',
      title: 'Test question',
      inputType: type,
      configuration: type == QuizInputType.slider
          ? {'min': 0, 'max': 100, 'step': 1}
          : null,
      choices: choices,
    );

void main() {
  group('StepRenderer', () {
    testWidgets('renders SliderInput for QuizInputType.slider', (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.slider),
          value: 50.0,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(SliderInput), findsOneWidget);
    });

    testWidgets('renders ChoiceInput for QuizInputType.choice', (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.choice, choices: [
            const QuizChoice(id: 'a', label: 'Option A'),
            const QuizChoice(id: 'b', label: 'Option B'),
          ]),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(ChoiceInput), findsOneWidget);
    });

    testWidgets('renders MultiChoiceInput for QuizInputType.multiChoice',
        (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.multiChoice, choices: [
            const QuizChoice(id: 'a', label: 'Option A'),
            const QuizChoice(id: 'b', label: 'Option B'),
          ]),
          value: const <String>[],
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(MultiChoiceInput), findsOneWidget);
    });

    testWidgets('renders TextInput for QuizInputType.text', (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.text),
          value: '',
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(TextInput), findsOneWidget);
    });

    testWidgets('renders NumberInput for QuizInputType.number', (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.number),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(NumberInput), findsOneWidget);
    });

    testWidgets('renders DateInput for QuizInputType.date', (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.date),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(DateInput), findsOneWidget);
    });

    testWidgets(
        'renders InfoPanel for QuizInputType.noneJustInformation',
        (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.noneJustInformation),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(InfoPanel), findsOneWidget);
    });

    testWidgets('passes validationMessage to the child widget', (tester) async {
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.text),
          value: '',
          onChanged: (_) {},
          validationMessage: 'This field is required',
        ),
      ));
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('calls onChanged when value changes', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        StepRenderer(
          spec: _spec(QuizInputType.text),
          value: '',
          onChanged: (v) => emitted = v,
        ),
      ));
      await tester.enterText(find.byType(TextField), 'hello');
      expect(emitted, 'hello');
    });
  });
}
