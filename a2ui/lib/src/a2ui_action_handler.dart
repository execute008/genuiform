// Subscribes to `genui.SurfaceController.onSubmit` and translates the
// Restart action carried by an in-Surface Button into a Dart callback.
//
// ─── Subscription target ─────────────────────────────────────────────────────
//
// `genui.SurfaceController` exposes:
//
//   Stream<ChatMessage> get onSubmit
//
// When the user taps a Button whose `action` is `{"event":{"name":"..."}}`,
// the catalog's `_handlePress` calls
// `controller.handleUiEvent(UserActionEvent(...))`, which adds a
// `ChatMessage` carrying a `UiInteractionPart` (MIME
// `application/vnd.genui.interaction+json`). The interaction JSON has the
// shape `{"version":"v0.9","action":{"name":"...","..."}}`.
//
// We listen on `onSubmit` directly without constructing a
// `genui.Conversation` — `Conversation` adds LLM-transport wiring we don't
// need here, so we'd just be paying for a no-op transport stub.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart' as genui;

import 'a2ui_outcome_prompt.dart';

/// Subscribes to [genui.SurfaceController.onSubmit] and fires [onRestart]
/// when an action with name [actionName] arrives. All other action names
/// are ignored (logged in debug mode).
///
/// Lifecycle:
/// 1. Call [start] after constructing the [controller].
/// 2. Call [dispose] in the owning widget's `dispose()`.
class A2uiActionHandler {
  A2uiActionHandler({
    required this.controller,
    required this.onRestart,
    this.actionName = kA2uiRestartAction,
  });

  final genui.SurfaceController controller;
  final VoidCallback onRestart;

  /// The A2UI action name routed to [onRestart].  Defaults to
  /// [kA2uiRestartAction].
  final String actionName;

  StreamSubscription<genui.ChatMessage>? _sub;

  /// Idempotent — calling [start] twice is a no-op.
  void start() {
    if (_sub != null) return;
    _sub = controller.onSubmit.listen(_handleMessage);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _handleMessage(genui.ChatMessage message) {
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
      final interactionJson = wrapper['interaction'] as String?;
      if (interactionJson == null) return;

      final payload = jsonDecode(interactionJson) as Map<String, Object?>;
      final action = payload['action'] as Map<String, Object?>?;
      if (action == null) return;

      final name = action['name'] as String?;
      if (name == null) return;

      if (name == actionName) {
        onRestart();
      } else {
        debugPrint('A2uiActionHandler: ignoring unknown action "$name"');
      }
    } catch (e, stack) {
      debugPrint('A2uiActionHandler: error decoding interaction part: $e\n$stack');
    }
  }
}
