// Copyright 2026 Oskar Freye — genuiform workbench
//
// Phase 4 of the A2UI v2 spec (§4.4): renderer rewrite.
//
// ─── Stream path (a2uiMessageStream != null) ────────────────────────────────
//
// When [A2uiOutcomeRenderer.a2uiMessageStream] is provided, each text chunk
// from the stream is fed into [genui.A2uiTransportAdapter.addChunk]. The
// adapter internally runs the chunks through [genui.A2uiParserTransformer]
// and emits parsed [genui.A2uiMessage]s on its [incomingMessages] stream.
// We subscribe to [incomingMessages] and forward each message to
// [SurfaceController.handleMessage] — exactly the pattern used by
// [genui.Conversation] in conversation.dart line 119.
//
// ─── Fallback path ──────────────────────────────────────────────────────────
//
// If [a2uiMessageStream] is null, or the stream errors, or the stream
// completes without any messages being successfully dispatched, we fall back
// to the v1 hand-crafted [genui.CreateSurface] + [genui.UpdateComponents]
// pair (the original PoC behavior). In that fallback, the [UpdateComponents]
// includes a Button with `workbench/restart` action so the in-Surface Restart
// still fires [onRestart] via [A2uiActionHandler].
//
// ─── Action handler ─────────────────────────────────────────────────────────
//
// [A2uiActionHandler] is created in [initState] and wired before any messages
// are dispatched. It subscribes to [SurfaceController.onSubmit] and calls
// [onRestart] when a `workbench/restart` action fires. Disposed before
// [_controller] in [dispose].
//
// ─── Restart button placement ────────────────────────────────────────────────
//
// The Restart button now lives inside the Surface (either LLM-emitted or the
// fallback hand-crafted tree). The outside-the-Surface Restart button is
// removed from release builds. In kDebugMode a secondary outside-the-Surface
// Restart button is kept below the footer as a safety net (§5.3).
//
// ─── A2uiTransportAdapter API used ──────────────────────────────────────────
//
// Method: `A2uiTransportAdapter.addChunk(String text)`
//   Verified at:
//   ~/.pub-cache/hosted/pub.dev/genui-0.9.0/lib/src/transport/a2ui_transport_adapter.dart
//   line 49 — accepts a text chunk, runs it through A2uiParserTransformer,
//   and emits parsed A2uiMessage instances on [incomingMessages].
//
// Stream: `A2uiTransportAdapter.incomingMessages` → `Stream<A2uiMessage>`
//   We subscribe to this and forward each message to [_controller.handleMessage].
//   (Same pattern as genui.Conversation — see conversation.dart line 119.)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart' as genui;

import '../registry/handoff_registry.dart';
import 'a2ui_action_handler.dart';

/// Renders the per-outcome handoff screen via Google's `genui` SDK.
///
/// ### Stream path
///
/// When [a2uiMessageStream] is non-null, chunks are fed into
/// [genui.A2uiTransportAdapter.addChunk]. Parsed A2UI messages are forwarded
/// to the [genui.SurfaceController]. The [genui.Surface] renders the live tree.
///
/// ### Fallback path
///
/// When [a2uiMessageStream] is null, or when the stream errors/completes
/// before any messages arrive, the v1 hand-crafted tree is dispatched
/// directly. A "fallback" badge is shown above the Surface in [kDebugMode].
///
/// ### Action handler
///
/// An [A2uiActionHandler] is wired to [genui.SurfaceController.onSubmit] so
/// that the `workbench/restart` action (fired by the Button inside the Surface)
/// calls [onRestart]. Both the live LLM tree and the fallback hand-crafted tree
/// include a Button with this action.
///
/// ### Restart button
///
/// - **Inside the Surface** — always present (LLM-emitted or fallback).
/// - **Outside the Surface** — only in [kDebugMode] as a safety net (§5.3).
class A2uiOutcomeRenderer extends StatefulWidget {
  const A2uiOutcomeRenderer({
    required this.outcomeId,
    required this.handoff,
    required this.onRestart,
    this.a2uiMessageStream,
    super.key,
  });

  final String outcomeId;

  /// May be null if the parsed DSL had no handoff registered for this outcome.
  final SimulatedHandoff? handoff;

  final VoidCallback onRestart;

  /// When non-null, chunks from this stream are fed into the transport adapter
  /// instead of using the v1 hand-crafted messages.
  final Stream<String>? a2uiMessageStream;

  @override
  State<A2uiOutcomeRenderer> createState() => _A2uiOutcomeRendererState();
}

class _A2uiOutcomeRendererState extends State<A2uiOutcomeRenderer> {
  late final genui.SurfaceController _controller;
  late final String _surfaceId;
  late final A2uiActionHandler _actionHandler;

  // Transport adapter used only in the stream path.
  genui.A2uiTransportAdapter? _transportAdapter;
  StreamSubscription<genui.A2uiMessage>? _incomingMessagesSub;
  StreamSubscription<String>? _streamSub;

  /// True once at least one A2uiMessage has been dispatched via the adapter.
  bool _receivedAnyMessage = false;

  /// True when we fell back to the v1 hand-crafted tree because the stream
  /// path failed (error or completed with zero messages).
  bool _usedFallback = false;

  static const _catalogId =
      'https://a2ui.org/specification/v0_9/basic_catalog.json';

  @override
  void initState() {
    super.initState();
    _surfaceId = 'outcome_${widget.outcomeId}';
    _controller = genui.SurfaceController(
      catalogs: [genui.BasicCatalogItems.asCatalog()],
    );

    // Wire the action handler BEFORE any messages are dispatched (§4.4).
    _actionHandler = A2uiActionHandler(
      controller: _controller,
      onRestart: widget.onRestart,
    );
    _actionHandler.start();

    if (widget.a2uiMessageStream != null) {
      _startStreamPath(widget.a2uiMessageStream!);
    } else {
      _seedFallbackSurface();
    }
  }

  @override
  void dispose() {
    _actionHandler.dispose();
    _streamSub?.cancel();
    _incomingMessagesSub?.cancel();
    _transportAdapter?.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ─── Stream path ────────────────────────────────────────────────────────────

  void _startStreamPath(Stream<String> stream) {
    _transportAdapter = genui.A2uiTransportAdapter();

    // Forward parsed A2uiMessages from the adapter into the controller.
    // This mirrors the pattern in genui.Conversation (conversation.dart:119).
    _incomingMessagesSub = _transportAdapter!.incomingMessages.listen(
      (message) {
        _controller.handleMessage(message);
        if (!_receivedAnyMessage) {
          setState(() {
            _receivedAnyMessage = true;
          });
        }
      },
    );

    // Feed each chunk from the stream into the transport adapter.
    _streamSub = stream.listen(
      (chunk) {
        _transportAdapter!.addChunk(chunk);
      },
      onError: (Object error, StackTrace stack) {
        debugPrint(
          'A2uiOutcomeRenderer: stream error — falling back to v1 tree. '
          'Error: $error',
        );
        _applyFallback();
      },
      onDone: () {
        // The A2uiParserTransformer pipeline delivers its events
        // asynchronously on the next microtask cycle, so we defer the
        // "no messages" check by one microtask to let any pending
        // A2uiMessageEvent dispatches reach _receivedAnyMessage first.
        Future<void>.microtask(() {
          if (!mounted) return;
          if (!_receivedAnyMessage) {
            debugPrint(
              'A2uiOutcomeRenderer: stream completed with no messages '
              '— falling back to v1 tree.',
            );
            _applyFallback();
          }
        });
      },
      cancelOnError: true,
    );
  }

  /// Called when the stream path fails. Dispatches the v1 hand-crafted tree.
  void _applyFallback() {
    setState(() {
      _usedFallback = true;
    });
    _seedFallbackSurface();
  }

  // ─── Fallback path ──────────────────────────────────────────────────────────

  /// Dispatches the v1 hand-crafted [genui.CreateSurface] +
  /// [genui.UpdateComponents] messages.
  ///
  /// The tree includes a Button with the `workbench/restart` action so the
  /// in-Surface Restart still works regardless of which path rendered.
  void _seedFallbackSurface() {
    _controller.handleMessage(
      genui.CreateSurface(
        surfaceId: _surfaceId,
        catalogId: _catalogId,
      ),
    );

    final headline = widget.handoff?.label ?? 'Form completed';
    final subtext = widget.handoff != null
        ? 'Outcome reached: ${widget.outcomeId}.'
        : 'Outcome reached: ${widget.outcomeId} (no handoff registered).';

    _controller.handleMessage(
      genui.UpdateComponents(
        surfaceId: _surfaceId,
        components: [
          const genui.Component(
            id: 'root',
            type: 'Column',
            properties: {
              'distribution': 'center',
              'alignment': 'center',
              'children': ['headline', 'subtext', 'restart_btn'],
            },
          ),
          genui.Component(
            id: 'headline',
            type: 'Text',
            properties: {
              'text': headline,
              'variant': 'h2',
            },
          ),
          genui.Component(
            id: 'subtext',
            type: 'Text',
            properties: {
              'text': subtext,
              'variant': 'body',
            },
          ),
          const genui.Component(
            id: 'restart_label',
            type: 'Text',
            properties: {'text': 'Restart'},
          ),
          const genui.Component(
            id: 'restart_btn',
            type: 'Button',
            properties: {
              'child': 'restart_label',
              'variant': 'primary',
              'action': {
                'event': {'name': 'workbench/restart'},
              },
            },
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine footer text based on path and build mode.
    final bool showFallbackFooter = kDebugMode && _usedFallback;
    final footerText = showFallbackFooter
        ? 'fallback A2UI tree (LLM emit failed)'
        : 'rendered live by Vertex via flutter/genui (A2UI v0.9)';
    final footerIcon = showFallbackFooter
        ? Icons.warning_amber_rounded
        : Icons.electric_bolt;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fallback badge (debug-only) ──────────────────────────────────
          if (kDebugMode && _usedFallback)
            Container(
              color: theme.colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'fallback (LLM emit failed)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),

          // ── A2UI-rendered outcome screen ─────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: genui.Surface(
                surfaceContext: _controller.contextFor(_surfaceId),
              ),
            ),
          ),

          // ── Footer badge ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  footerIcon,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  footerText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── Debug-only secondary Restart (§5.3 safety net) ───────────────
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: OutlinedButton.icon(
                onPressed: widget.onRestart,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart (debug)'),
              ),
            ),
        ],
      ),
    );
  }
}
