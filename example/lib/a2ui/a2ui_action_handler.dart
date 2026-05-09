// Translates the in-Surface Restart action into the page's restart callback.
//
// Ported from `workbench/lib/src/preview/a2ui_action_handler.dart`. See that
// file for the full subscription wiring rationale. The example handler
// listens for [kA2uiRestartAction] (`example/restart`) instead of
// `workbench/restart`.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart' as genui;

import 'a2ui_outcome_prompt.dart';

/// Subscribes to [genui.SurfaceController.onSubmit] and fires [onRestart]
/// when an [kA2uiRestartAction] action arrives.
class A2uiActionHandler {
  A2uiActionHandler({
    required this.controller,
    required this.onRestart,
  });

  final genui.SurfaceController controller;
  final VoidCallback onRestart;

  StreamSubscription<genui.ChatMessage>? _sub;

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

      if (name == kA2uiRestartAction) {
        onRestart();
      } else {
        debugPrint('A2uiActionHandler: ignoring unknown action "$name"');
      }
    } catch (e, stack) {
      debugPrint('A2uiActionHandler: error decoding interaction part: $e\n$stack');
    }
  }
}
