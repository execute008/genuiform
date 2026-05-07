// Tests for workbench/lib/src/preview/a2ui_action_handler.dart
//
// Covers Phase 3 of the A2UI v2 spec (§4.3):
//   1. Positive: tapping a Button with action `workbench/restart` fires onRestart.
//   2. Negative: tapping a Button with action `workbench/other` does NOT fire onRestart.
//
// The test drives a real `genui.SurfaceController` + `genui.Surface` widget so
// that the full button→dispatchEvent→onSubmit chain is exercised — not mocked.
//
// No LLM transport or `genui.Conversation` is required because
// `A2uiActionHandler` subscribes directly to `SurfaceController.onSubmit`
// (see the file header of a2ui_action_handler.dart for the full rationale).

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;

import 'package:genuiform_workbench/src/preview/a2ui_action_handler.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _kSurfaceId = 'test_surface';
const _kCatalogId = 'https://a2ui.org/specification/v0_9/basic_catalog.json';

// IDs used in both tests via the shared surface.
const _kButtonId = 'restart_btn';
const _kLabelId = 'restart_label';
const _kOtherButtonId = 'other_btn';
const _kOtherLabelId = 'other_label';

/// Builds the complete surface with two buttons: one `workbench/restart` and
/// one `workbench/other`.
void _seedTwoButtonSurface(genui.SurfaceController controller) {
  controller.handleMessage(
    genui.CreateSurface(surfaceId: _kSurfaceId, catalogId: _kCatalogId),
  );
  controller.handleMessage(
    genui.UpdateComponents(
      surfaceId: _kSurfaceId,
      components: [
        const genui.Component(
          id: 'root',
          type: 'Column',
          properties: {
            'children': [_kButtonId, _kOtherButtonId],
          },
        ),
        const genui.Component(
          id: _kLabelId,
          type: 'Text',
          properties: {'text': 'Restart form'},
        ),
        const genui.Component(
          id: _kButtonId,
          type: 'Button',
          properties: {
            'child': _kLabelId,
            'variant': 'primary',
            'action': {
              'event': {'name': 'workbench/restart'},
            },
          },
        ),
        const genui.Component(
          id: _kOtherLabelId,
          type: 'Text',
          properties: {'text': 'Other action'},
        ),
        const genui.Component(
          id: _kOtherButtonId,
          type: 'Button',
          properties: {
            'child': _kOtherLabelId,
            'action': {
              'event': {'name': 'workbench/other'},
            },
          },
        ),
      ],
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('A2uiActionHandler', () {
    late genui.SurfaceController controller;
    late A2uiActionHandler handler;
    late int restartCallCount;

    setUp(() {
      restartCallCount = 0;
      controller = genui.SurfaceController(
        catalogs: [genui.BasicCatalogItems.asCatalog()],
      );
      handler = A2uiActionHandler(
        controller: controller,
        onRestart: () => restartCallCount++,
      );
      handler.start();
    });

    tearDown(() {
      handler.dispose();
      controller.dispose();
    });

    // ── Positive case ─────────────────────────────────────────────────────────
    testWidgets(
      'fires onRestart exactly once when the workbench/restart button is tapped',
      (WidgetTester tester) async {
        _seedTwoButtonSurface(controller);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: genui.Surface(
                surfaceContext: controller.contextFor(_kSurfaceId),
              ),
            ),
          ),
        );

        // Let async rendering settle (surface builds CatalogItem widgets).
        await tester.pumpAndSettle();

        // Tap the restart button (identified by its label text).
        expect(find.text('Restart form'), findsOneWidget);
        await tester.tap(find.text('Restart form'));
        await tester.pump();

        expect(restartCallCount, 1, reason: 'onRestart should fire exactly once');
      },
    );

    // ── Negative case ─────────────────────────────────────────────────────────
    testWidgets(
      'does NOT fire onRestart when a button with action workbench/other is tapped',
      (WidgetTester tester) async {
        _seedTwoButtonSurface(controller);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: genui.Surface(
                surfaceContext: controller.contextFor(_kSurfaceId),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the "other" button.
        expect(find.text('Other action'), findsOneWidget);
        await tester.tap(find.text('Other action'));
        await tester.pump();

        expect(restartCallCount, 0, reason: 'onRestart should NOT fire for workbench/other');
      },
    );

    // ── Idempotency of start() ────────────────────────────────────────────────
    test('start() is idempotent — calling it twice does not double-subscribe', () async {
      _seedTwoButtonSurface(controller);

      // Call start() a second time.
      handler.start();

      // Directly fire a ChatMessage through the controller to simulate a
      // button tap without needing a widget tree.
      // We verify by counting: if start() were NOT idempotent, two subscriptions
      // would both call onRestart → restartCallCount == 2.
      //
      // Since we can't tap without a widget, we use a simpler approach:
      // manually call handleUiEvent to put a message on onSubmit.
      controller.handleUiEvent(
        genui.UserActionEvent(
          name: 'workbench/restart',
          sourceComponentId: 'fake_btn',
        ),
      );

      // Give the stream a microtask to deliver the event.
      await Future<void>.delayed(Duration.zero);

      expect(
        restartCallCount,
        1,
        reason: 'double start() should not cause double callback invocation',
      );
    });

    // ── dispose() cancels subscription ────────────────────────────────────────
    test('dispose() cancels subscription so no further callbacks fire', () async {
      handler.dispose();

      controller.handleUiEvent(
        genui.UserActionEvent(
          name: 'workbench/restart',
          sourceComponentId: 'fake_btn',
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(restartCallCount, 0, reason: 'onRestart must not fire after dispose()');
    });
  });
}
