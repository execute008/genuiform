import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/widgets/streaming_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('StreamingIndicator', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const StreamingIndicator()));
      expect(find.byType(StreamingIndicator), findsOneWidget);
    });

    testWidgets('renders dot indicators', (tester) async {
      await tester.pumpWidget(_wrap(const StreamingIndicator()));
      // Dot indicators should be visible — there are 3 dots
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });

    testWidgets('renders with optional label', (tester) async {
      await tester.pumpWidget(_wrap(
        const StreamingIndicator(label: 'Thinking…'),
      ));
      expect(find.text('Thinking…'), findsOneWidget);
    });

    testWidgets('advances animation after 300ms pump', (tester) async {
      await tester.pumpWidget(_wrap(const StreamingIndicator()));
      // Initial render
      await tester.pump(const Duration(milliseconds: 300));
      // Animation should advance without throwing
      expect(find.byType(StreamingIndicator), findsOneWidget);
    });

    testWidgets('full 600ms cycle completes without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const StreamingIndicator()));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(StreamingIndicator), findsOneWidget);
    });

    testWidgets('can be removed from widget tree without throwing',
        (tester) async {
      // First, mount the widget
      await tester.pumpWidget(_wrap(const StreamingIndicator()));
      expect(find.byType(StreamingIndicator), findsOneWidget);

      // Then replace with an empty container — controller must dispose cleanly
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(find.byType(StreamingIndicator), findsNothing);
    });

    testWidgets('no label shown when label is null', (tester) async {
      await tester.pumpWidget(_wrap(const StreamingIndicator()));
      // No text widgets except possible inherited ones
      expect(find.text('Thinking…'), findsNothing);
    });
  });
}
