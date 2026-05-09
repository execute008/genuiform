import 'package:flutter_test/flutter_test.dart';

import 'package:genuiform_workbench/main.dart';

void main() {
  testWidgets(
    'Workbench renders the credentials gate when no dart-defines are present',
    (WidgetTester tester) async {
      await tester.pumpWidget(const WorkbenchApp());
      await tester.pump();

      // Phase 1 root: top-bar title + credentials gate (because the test runs
      // without --dart-define=GEMINI_API_KEY / VERTEX_API_KEY=...).
      expect(find.text('genuiform workbench'), findsOneWidget);
      expect(find.text('Pick a transport to start'), findsOneWidget);
      expect(find.text('Gemini API key (AIza…)'), findsOneWidget);
    },
  );
}
