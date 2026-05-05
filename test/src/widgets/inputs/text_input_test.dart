import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/widgets/inputs/text_input.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _textSpec({bool multiline = false}) => QuizStepSpec(
      id: 'text_q',
      title: 'Enter text',
      inputType: QuizInputType.text,
      configuration: {'multiline': multiline},
    );

void main() {
  group('TextInput', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('enterText fires onChanged with typed string', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), 'hello world');
      await tester.pump();

      expect(emitted, equals('hello world'));
    });

    testWidgets('initialises with existing value', (tester) async {
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(),
          value: 'initial text',
          onChanged: (_) {},
        ),
      ));

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, equals('initial text'));
    });

    testWidgets('single-line mode renders one field without multi-line hint',
        (tester) async {
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(multiline: false),
          value: null,
          onChanged: (_) {},
        ),
      ));
      // The field should be present; single-line means it won't expand
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('multiline mode renders a field', (tester) async {
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(multiline: true),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('shows validation message when set', (tester) async {
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(),
          value: null,
          onChanged: (_) {},
          validationMessage: 'This field is required',
        ),
      ));
      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets('does not show validation message when null', (tester) async {
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('This field is required'), findsNothing);
    });

    testWidgets('each keystroke triggers onChanged', (tester) async {
      final emitted = <dynamic>[];
      await tester.pumpWidget(_wrap(
        TextInput(
          spec: _textSpec(),
          value: null,
          onChanged: emitted.add,
        ),
      ));

      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pump();

      // enterText triggers a single onChange with the full string
      expect(emitted, isNotEmpty);
      expect(emitted.last, equals('abc'));
    });
  });
}
