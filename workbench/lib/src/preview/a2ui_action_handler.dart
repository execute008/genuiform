// Copyright 2026 Oskar Freye — genuiform workbench
//
// Wires `genui.SurfaceController.onSubmit` to the `onRestart` callback for
// Phase 3 of the A2UI v2 spec (§4.3).
//
// ─── Subscription target ─────────────────────────────────────────────────────
//
// `genui.SurfaceController` exposes:
//
//   Stream<ChatMessage> get onSubmit
//     — see ~/.pub-cache/hosted/pub.dev/genui-0.9.0/lib/src/engine/surface_controller.dart:72
//
// When the user taps a Button whose `action` is `{"event": {"name": "..."}}`,
// the catalog's `_handlePress` function calls:
//   itemContext.dispatchEvent(UserActionEvent(name: actionName, ...))
//   → controller.handleUiEvent(event)
//   → _onSubmit.add(ChatMessage.user('', parts: [UiInteractionPart.create(
//         jsonEncode({'version': 'v0.9', 'action': event.toMap()}))]))
//
// The resulting `ChatMessage` carries a `UiInteractionPart` (MIME type
// `application/vnd.genui.interaction+json`) whose `interaction` field is the
// JSON string above. The `'action'` map in that JSON has a top-level `'name'`
// key — matching `UserActionEvent.name`.
//
// ─── No Conversation needed ──────────────────────────────────────────────────
//
// `SurfaceController.onSubmit` is accessible directly without constructing a
// `genui.Conversation`. The `Conversation` facade adds LLM-transport wiring
// (it subscribes to `onSubmit` via `_engineSubmitSubscription` and calls
// `sendRequest`), but we only need the stream itself — so we skip `Conversation`
// entirely. This keeps the handler self-contained and avoids a no-op transport
// stub.
//
// ─── Handler responsibility ──────────────────────────────────────────────────
//
// This handler is workbench-only plumbing (spec §2 constraint 4). It does NOT
// propagate events into genuiform's `FormController`. It only translates the
// `workbench/restart` action into the supplied `onRestart` callback.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart' as genui;

/// Subscribes to [genui.SurfaceController.onSubmit] and translates the
/// `workbench/restart` A2UI action into the supplied [onRestart] callback.
///
/// All other action names are ignored (logged in debug mode).
///
/// Lifecycle:
/// 1. Call [start] after initialising the [controller].
/// 2. Call [dispose] in the owning widget's `dispose()` method.
class A2uiActionHandler {
  A2uiActionHandler({
    required this.controller,
    required this.onRestart,
  });

  /// The `genui.SurfaceController` whose [genui.SurfaceController.onSubmit]
  /// stream this handler listens to.
  final genui.SurfaceController controller;

  /// Called when a `workbench/restart` action fires inside the Surface.
  final VoidCallback onRestart;

  StreamSubscription<genui.ChatMessage>? _sub;

  /// Subscribes to [controller.onSubmit].
  ///
  /// Idempotent — calling [start] twice is a no-op.
  void start() {
    if (_sub != null) return;
    _sub = controller.onSubmit.listen(_handleMessage);
  }

  /// Cancels the subscription and releases resources.
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _handleMessage(genui.ChatMessage message) {
    // Extract all UiInteractionPart payloads from the message.
    final interactionParts = message.parts
        .whereType<genui.DataPart>()
        .where((p) => p.mimeType == genui.UiPartConstants.interactionMimeType);

    for (final part in interactionParts) {
      _handleInteractionPart(part);
    }
  }

  void _handleInteractionPart(genui.DataPart part) {
    try {
      final wrapper =
          jsonDecode(utf8.decode(part.bytes)) as Map<String, Object?>;
      // The UiInteractionPart wraps the interaction JSON string in {"interaction": "..."}
      final interactionJson = wrapper['interaction'] as String?;
      if (interactionJson == null) return;

      final payload =
          jsonDecode(interactionJson) as Map<String, Object?>;
      // Shape: {"version": "v0.9", "action": {"name": "...", ...}}
      final action = payload['action'] as Map<String, Object?>?;
      if (action == null) return;

      final name = action['name'] as String?;
      if (name == null) return;

      if (name == 'workbench/restart') {
        onRestart();
      } else {
        debugPrint(
          'A2uiActionHandler: ignoring unknown action "$name"',
        );
      }
    } catch (e, stack) {
      debugPrint('A2uiActionHandler: error decoding interaction part: $e\n$stack');
    }
  }
}
