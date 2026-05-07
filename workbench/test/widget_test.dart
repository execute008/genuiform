import 'package:flutter_test/flutter_test.dart';

import 'package:genuiform_workbench/main.dart';

void main() {
  testWidgets('Workbench renders placeholder text', (WidgetTester tester) async {
    await tester.pumpWidget(const WorkbenchApp());

    expect(find.text('Hello workbench — Phase 0 OK'), findsOneWidget);
  });
}
