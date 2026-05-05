import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/icons/icon_registry.dart';
import 'package:genuiform/src/models/quiz_choice.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';
import 'package:genuiform/src/models/quiz_step_spec.dart';
import 'package:genuiform/src/widgets/inputs/multi_choice_input.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

QuizStepSpec _multiSpec(List<QuizChoice> choices) => QuizStepSpec(
      id: 'multi_q',
      title: 'Pick all that apply',
      inputType: QuizInputType.multiChoice,
      choices: choices,
    );

const _choices = [
  QuizChoice(id: 'opt_a', label: 'Option A', iconName: 'star'),
  QuizChoice(id: 'opt_b', label: 'Option B', iconName: 'flag'),
  QuizChoice(id: 'opt_c', label: 'Option C'),
];

void main() {
  group('MultiChoiceInput', () {
    testWidgets('renders all choices without throwing', (tester) async {
      await tester.pumpWidget(_wrap(
        MultiChoiceInput(
          spec: _multiSpec(_choices),
          value: const <dynamic>[],
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);
      expect(find.text('Option C'), findsOneWidget);
    });

    testWidgets('tapping a choice adds it to the list', (tester) async {
      dynamic emitted;
      await tester.pumpWidget(_wrap(
        MultiChoiceInput(
          spec: _multiSpec(_choices),
          value: const <dynamic>[],
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.text('Option A'));
      await tester.pump();

      expect(emitted, isA<List>());
      expect(emitted as List, contains('opt_a'));
    });

    testWidgets('tapping two choices emits a list of two ids', (tester) async {
      dynamic emitted;

      // Start with empty selection
      late StateSetter stateSetter;
      dynamic currentValue = const <dynamic>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                stateSetter = setState;
                return SingleChildScrollView(
                  child: MultiChoiceInput(
                    spec: _multiSpec(_choices),
                    value: currentValue,
                    onChanged: (v) {
                      emitted = v;
                      stateSetter(() => currentValue = v);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Option A'));
      await tester.pump();

      await tester.tap(find.text('Option B'));
      await tester.pump();

      expect(emitted, isA<List>());
      final list = emitted as List;
      expect(list, containsAll(['opt_a', 'opt_b']));
      expect(list.length, equals(2));
    });

    testWidgets('tapping a selected choice removes it from the list',
        (tester) async {
      dynamic emitted;
      late StateSetter stateSetter;
      dynamic currentValue = const ['opt_a', 'opt_b'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                stateSetter = setState;
                return SingleChildScrollView(
                  child: MultiChoiceInput(
                    spec: _multiSpec(_choices),
                    value: currentValue,
                    onChanged: (v) {
                      emitted = v;
                      stateSetter(() => currentValue = v);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Deselect opt_a
      await tester.tap(find.text('Option A'));
      await tester.pump();

      expect(emitted, isA<List>());
      final list = emitted as List;
      expect(list, contains('opt_b'));
      expect(list, isNot(contains('opt_a')));
      expect(list.length, equals(1));
    });

    testWidgets('icon resolution works for known icon names', (tester) async {
      expect(IconRegistry.resolve('star'), isNotNull);
      expect(IconRegistry.resolve('flag'), isNotNull);

      await tester.pumpWidget(_wrap(
        MultiChoiceInput(
          spec: _multiSpec(_choices),
          value: const <dynamic>[],
          onChanged: (_) {},
        ),
      ));

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('shows validation message when set', (tester) async {
      await tester.pumpWidget(_wrap(
        MultiChoiceInput(
          spec: _multiSpec(_choices),
          value: const <dynamic>[],
          onChanged: (_) {},
          validationMessage: 'Select at least one',
        ),
      ));
      expect(find.text('Select at least one'), findsOneWidget);
    });

    testWidgets('text-field choice emits map in list', (tester) async {
      const textFieldChoices = [
        QuizChoice(id: 'other', label: 'Other', isTextField: true),
      ];

      dynamic emitted;
      await tester.pumpWidget(_wrap(
        MultiChoiceInput(
          spec: _multiSpec(textFieldChoices),
          value: const <dynamic>[],
          onChanged: (v) => emitted = v,
        ),
      ));

      await tester.tap(find.text('Other'));
      await tester.pump();

      expect(emitted, isA<List>());
      final list = emitted as List;
      expect(list.length, equals(1));
      expect(list.first, isA<Map>());
      expect((list.first as Map)['choice'], equals('other'));
    });
  });
}
