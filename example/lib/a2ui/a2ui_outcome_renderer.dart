// Renders a per-outcome handoff screen via Google's `genui` SDK.
//
// Ported from `workbench/lib/src/preview/a2ui_outcome_renderer.dart`. See that
// file for the full description of the stream / fallback paths and why we
// subscribe to `A2uiTransportAdapter.incomingMessages`. The example renderer
// differs from the workbench by:
//   - using [kA2uiRestartAction] (`example/restart`) for the in-Surface Button
//   - simpler footer copy (no debug-only Restart safety net)

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart' as genui;

import 'a2ui_action_handler.dart';
import 'a2ui_outcome_prompt.dart';
import 'simulated_handoff.dart';

/// Renders a per-outcome handoff screen via the `genui` SDK.
///
/// When [a2uiMessageStream] is non-null, chunks are fed into a
/// [genui.A2uiTransportAdapter] and the parsed `A2uiMessage`s are forwarded
/// to a [genui.SurfaceController]. When the stream is null, errors, or
/// completes without dispatching any messages, a hand-crafted v1 tree is
/// dispatched directly so the user always sees an outcome screen.
class A2uiOutcomeRenderer extends StatefulWidget {
  const A2uiOutcomeRenderer({
    required this.outcomeId,
    required this.handoff,
    required this.onRestart,
    this.a2uiMessageStream,
    super.key,
  });

  final String outcomeId;
  final SimulatedHandoff? handoff;
  final VoidCallback onRestart;
  final Stream<String>? a2uiMessageStream;

  @override
  State<A2uiOutcomeRenderer> createState() => _A2uiOutcomeRendererState();
}

class _A2uiOutcomeRendererState extends State<A2uiOutcomeRenderer> {
  late final genui.SurfaceController _controller;
  late final String _surfaceId;
  late final A2uiActionHandler _actionHandler;

  genui.A2uiTransportAdapter? _transportAdapter;
  StreamSubscription<genui.A2uiMessage>? _incomingMessagesSub;
  StreamSubscription<String>? _streamSub;

  bool _receivedAnyMessage = false;
  bool _usedFallback = false;

  @override
  void initState() {
    super.initState();
    _surfaceId = 'outcome_${widget.outcomeId}';
    _controller = genui.SurfaceController(
      catalogs: [genui.BasicCatalogItems.asCatalog()],
    );

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

  void _startStreamPath(Stream<String> stream) {
    _transportAdapter = genui.A2uiTransportAdapter();

    _incomingMessagesSub = _transportAdapter!.incomingMessages.listen(
      (message) {
        _controller.handleMessage(message);
        if (!_receivedAnyMessage) {
          setState(() => _receivedAnyMessage = true);
        }
      },
    );

    _streamSub = stream.listen(
      (chunk) => _transportAdapter!.addChunk(chunk),
      onError: (Object error, StackTrace stack) {
        debugPrint(
          'A2uiOutcomeRenderer: stream error — falling back to v1 tree. '
          'Error: $error',
        );
        _applyFallback();
      },
      onDone: () {
        // The A2uiParserTransformer pipeline delivers parsed events on the
        // next microtask cycle, so defer the "no messages" check.
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

  void _applyFallback() {
    setState(() => _usedFallback = true);
    _seedFallbackSurface();
  }

  /// Hand-crafted v1 tree dispatched when the live LLM emit path is
  /// unavailable (no key, mock client, error, or timeout).
  void _seedFallbackSurface() {
    _controller.handleMessage(
      genui.CreateSurface(
        surfaceId: _surfaceId,
        catalogId: kA2uiBasicCatalogId,
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
            properties: {'text': headline, 'variant': 'h2'},
          ),
          genui.Component(
            id: 'subtext',
            type: 'Text',
            properties: {'text': subtext, 'variant': 'body'},
          ),
          const genui.Component(
            id: 'restart_label',
            type: 'Text',
            properties: {'text': 'Restart form'},
          ),
          const genui.Component(
            id: 'restart_btn',
            type: 'Button',
            properties: {
              'child': 'restart_label',
              'variant': 'primary',
              'action': {
                'event': {'name': kA2uiRestartAction},
              },
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showFallbackFooter = kDebugMode && _usedFallback;
    final footerText = _usedFallback
        ? 'fallback A2UI tree (no live emit)'
        : 'rendered live by Vertex via flutter/genui (A2UI v0.9)';
    final footerIcon =
        _usedFallback ? Icons.warning_amber_rounded : Icons.electric_bolt;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showFallbackFooter)
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
                    'fallback (no live emit)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: genui.Surface(
                surfaceContext: _controller.contextFor(_surfaceId),
              ),
            ),
          ),
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
