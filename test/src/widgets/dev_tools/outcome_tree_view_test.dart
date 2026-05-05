import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/genuiform.dart';

import '../../../_fixtures/sessions.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  group('OutcomeTreeView — rendering', () {
    testWidgets('renders root node id', (tester) async {
      final tree = gymgeistTree();
      await tester.pumpWidget(
        _wrap(OutcomeTreeView(root: tree, activePath: const [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('account_only'), findsOneWidget);
    });

    testWidgets('renders all node IDs in the gymgeist tree', (tester) async {
      final tree = gymgeistTree();
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 800,
            child: OutcomeTreeView(root: tree, activePath: const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Layers and their children should be present
      expect(find.text('account_only'), findsOneWidget);
      expect(find.text('with_workout_plan'), findsOneWidget);
      expect(find.text('nutrition_path'), findsOneWidget);
    });

    testWidgets('active path nodes have highlighted container border',
        (tester) async {
      final tree = gymgeistTree();
      const activePath = ['account_only', 'with_workout_plan'];

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 800,
            child: OutcomeTreeView(root: tree, activePath: activePath),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Containers with non-transparent borders — these are the
      // highlighted nodes. We verify two are highlighted (account_only +
      // with_workout_plan).
      final containers = tester.widgetList<Container>(find.byType(Container));
      final highlighted = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          final border = decoration.border;
          if (border is Border) {
            return border.top.width == 2;
          }
        }
        return false;
      }).toList();

      // At least 2 containers are highlighted (the two active nodes)
      expect(highlighted.length, greaterThanOrEqualTo(2));
    });

    testWidgets('inactive path nodes do not have thick border', (tester) async {
      final tree = gymgeistTree();

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 800,
            child: OutcomeTreeView(
              root: tree,
              activePath: const ['account_only'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only account_only should have width==2; others should have width==1
      final containers = tester.widgetList<Container>(find.byType(Container));
      final highlighted = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          final border = decoration.border;
          if (border is Border) {
            return border.top.width == 2;
          }
        }
        return false;
      }).toList();

      // Only 1 node highlighted
      expect(highlighted.length, equals(1));
    });

    testWidgets('renders with empty activePath without errors', (tester) async {
      final tree = gymgeistTree();
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 800,
            child: OutcomeTreeView(root: tree, activePath: const []),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No exception thrown; root node is rendered
      expect(find.text('account_only'), findsOneWidget);
    });

    testWidgets('renders single Outcome node', (tester) async {
      final tree = Outcome(
        id: 'done',
        contractDelta: Contract(fields: {}),
        handoff: null,
      );

      await tester.pumpWidget(
        _wrap(OutcomeTreeView(root: tree, activePath: const ['done'])),
      );
      await tester.pumpAndSettle();

      expect(find.text('done'), findsOneWidget);
    });
  });
}
