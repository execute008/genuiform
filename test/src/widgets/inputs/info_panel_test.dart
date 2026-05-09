import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/widgets/inputs/info_panel.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _infoSpec({
  String? information,
  String? description,
  String title = 'Important information',
}) =>
    QuizStepSpec(
      id: 'info_q',
      title: title,
      inputType: QuizInputType.noneJustInformation,
      description: description,
      configuration: {
        'information': information,
      }..removeWhere((_, v) => v == null),
    );

void main() {
  group('InfoPanel', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'Some info'),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('renders configuration information text', (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'This is the body text'),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('This is the body text'), findsOneWidget);
    });

    testWidgets(
        'falls back to spec.description when configuration information is absent',
        (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(description: 'Fallback description text'),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Fallback description text'), findsOneWidget);
    });

    testWidgets('renders spec.title as a header', (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(
            title: 'My Panel Title',
            information: 'Body text here',
          ),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('My Panel Title'), findsOneWidget);
    });

    testWidgets('Continue button is rendered', (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'Some info'),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('tapping Continue calls onChanged(true)', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'Read this'),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(emitted, equals(true));
    });

    testWidgets(
        'tapping Continue calls onChanged(true) then onSubmit, in order',
        (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'Read this'),
          value: null,
          onChanged: (v) => calls.add('changed:$v'),
          onSubmit: () => calls.add('submit'),
        ),
      ));

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(calls, equals(['changed:true', 'submit']));
    });

    testWidgets('tapping Continue without onSubmit only calls onChanged',
        (tester) async {
      var submitCalls = 0;
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'Read this'),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(emitted, equals(true));
      expect(submitCalls, equals(0));
    });

    testWidgets('shows validation message when set', (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'Info'),
          value: null,
          onChanged: (_) {},
          validationMessage: 'You must acknowledge',
        ),
      ));
      expect(find.text('You must acknowledge'), findsOneWidget);
    });

    testWidgets('does not show validation message when null', (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(information: 'Info'),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('You must acknowledge'), findsNothing);
    });

    testWidgets(
        'configuration information takes precedence over spec.description',
        (tester) async {
      await tester.pumpWidget(_wrap(
        InfoPanel(
          spec: _infoSpec(
            information: 'Config info text',
            description: 'Spec description text',
          ),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Config info text'), findsOneWidget);
      expect(find.text('Spec description text'), findsNothing);
    });
  });
}
