import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/icons/icon_registry.dart';
import 'package:genuiform/src/models/quiz_choice.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/widgets/inputs/choice_input.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _choiceSpec(List<QuizChoice> choices) => QuizStepSpec(
      id: 'choice_q',
      title: 'Pick one',
      inputType: QuizInputType.choice,
      choices: choices,
    );

const _choices = [
  QuizChoice(id: 'opt_a', label: 'Option A', iconName: 'star'),
  QuizChoice(id: 'opt_b', label: 'Option B', iconName: 'flag'),
  QuizChoice(id: 'opt_c', label: 'Option C', description: 'A description'),
];

void main() {
  group('ChoiceInput', () {
    testWidgets('renders all choices without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(_choices),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
      expect(find.text('Option C'), findsOneWidget);
    });

    testWidgets('renders choice descriptions', (tester) async {
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(_choices),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('A description'), findsOneWidget);
    });

    testWidgets('tapping a choice emits the choice id', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(_choices),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.text('Option A'));
      await tester.pump();

      expect(emitted, equals('opt_a'));
    });

    testWidgets('tapping a different choice emits the new id', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(_choices),
          value: 'opt_a',
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.text('Option B'));
      await tester.pump();

      expect(emitted, equals('opt_b'));
    });

    testWidgets('icon resolution works for known icon name', (tester) async {
      // Verify icon registry resolves 'star' before testing the widget
      final iconData = IconRegistry.resolve('star');
      expect(iconData, isNotNull);

      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(_choices),
          value: null,
          onChanged: (_) {},
        ),
      ));

      // Icons should be rendered for choices with iconNames
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('text-field choice emits map payload', (tester) async {
      const textFieldChoices = [
        QuizChoice(id: 'other', label: 'Other', isTextField: true),
      ];

      dynamic emitted;
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(textFieldChoices),
          value: null,
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.text('Other'));
      await tester.pump();

      // Initial tap emits map with empty text
      expect(emitted, isA<Map>());
      final emittedMap0 = emitted as Map<dynamic, dynamic>;
      expect(emittedMap0['choice'], equals('other'));
      expect(emittedMap0['text'], equals(''));
    });

    testWidgets('text-field choice shows text input when selected',
        (tester) async {
      const textFieldChoices = [
        QuizChoice(id: 'other', label: 'Other', isTextField: true),
      ];

      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(textFieldChoices),
          value: {'choice': 'other', 'text': ''},
          onChanged: (_) {},
        ),
      ));

      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('text-field choice typing emits map with text', (tester) async {
      const textFieldChoices = [
        QuizChoice(id: 'other', label: 'Other', isTextField: true),
      ];

      dynamic emitted;
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(textFieldChoices),
          value: {'choice': 'other', 'text': ''},
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'custom text');
      await tester.pump();

      expect(emitted, isA<Map>());
      final emittedMap = emitted as Map<dynamic, dynamic>;
      expect(emittedMap['choice'], equals('other'));
      expect(emittedMap['text'], equals('custom text'));
    });

    testWidgets('shows validation message when set', (tester) async {
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(_choices),
          value: null,
          onChanged: (_) {},
          validationMessage: 'Please select an option',
        ),
      ));
      expect(find.text('Please select an option'), findsOneWidget);
    });

    testWidgets('does not show validation message when null', (tester) async {
      await tester.pumpWidget(_wrap(
        ChoiceInput(
          spec: _choiceSpec(_choices),
          value: null,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Please select an option'), findsNothing);
    });
  });
}
