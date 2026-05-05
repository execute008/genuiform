import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform_example/api_key_panel.dart';

void main() {
  group('ApiKeyPanel', () {
    testWidgets('entering text and tapping Save updates the notifier',
        (tester) async {
      final notifier = ValueNotifier<String>('');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiKeyPanel(
              notifier: notifier,
              label: 'Test key',
            ),
          ),
        ),
      );

      // Enter a key in the TextField.
      await tester.enterText(find.byType(TextField), 'fake-key-12345');

      // Tap the Save button.
      await tester.tap(find.text('Save'));
      await tester.pump();

      // The notifier should be updated with the trimmed value.
      expect(notifier.value, equals('fake-key-12345'));

      notifier.dispose();
    });

    testWidgets('Save trims surrounding whitespace', (tester) async {
      final notifier = ValueNotifier<String>('');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiKeyPanel(
              notifier: notifier,
              label: 'Test key',
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '  padded-key  ');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(notifier.value, equals('padded-key'));

      notifier.dispose();
    });

    testWidgets('panel is pre-filled when notifier has an initial value',
        (tester) async {
      final notifier = ValueNotifier<String>('preset-value');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiKeyPanel(
              notifier: notifier,
              label: 'Test key',
            ),
          ),
        ),
      );

      // The TextField should be pre-populated from the notifier.
      expect(find.widgetWithText(TextField, 'preset-value'), findsOneWidget);

      notifier.dispose();
    });
  });
}
