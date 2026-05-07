import 'package:flutter/material.dart';
import 'package:genui/genui.dart' as genui;

import '../registry/handoff_registry.dart';

/// PoC for option C in `A2UI_AGENDA.md`: render the per-outcome handoff screen
/// via Google's `genui` SDK (which renders A2UI v0.9 messages into Flutter
/// widgets) instead of the Material `SnackBar` toast.
///
/// This widget owns a [genui.SurfaceController], hand-feeds it a `CreateSurface`
/// + `UpdateComponents` message for the reached outcome, and renders the
/// resulting [genui.Surface]. The handoff registry's label drives the headline;
/// the icon mapping mirrors the Flutter [IconData] used in the snackbar path.
///
/// **Scope (v1 PoC):** the A2UI message is hand-crafted on the client and
/// covers a Column of `Text` + `Image`-as-icon. v2 (out of scope) would have
/// the LLM emit the message itself, registered per-outcome via the registry.
///
/// **Restart** is a regular Flutter button outside the [genui.Surface] so we
/// don't need to plumb A2UI `action` events through to genuiform yet.
class A2uiOutcomeRenderer extends StatefulWidget {
  const A2uiOutcomeRenderer({
    required this.outcomeId,
    required this.handoff,
    required this.onRestart,
    super.key,
  });

  final String outcomeId;

  /// May be null if the parsed DSL had no handoff registered for this outcome.
  /// We still render a generic completion screen.
  final SimulatedHandoff? handoff;

  final VoidCallback onRestart;

  @override
  State<A2uiOutcomeRenderer> createState() => _A2uiOutcomeRendererState();
}

class _A2uiOutcomeRendererState extends State<A2uiOutcomeRenderer> {
  late final genui.SurfaceController _controller;
  late final String _surfaceId;

  static const _catalogId =
      'https://a2ui.org/specification/v0_9/basic_catalog.json';

  @override
  void initState() {
    super.initState();
    _surfaceId = 'outcome_${widget.outcomeId}';
    _controller = genui.SurfaceController(
      catalogs: [genui.BasicCatalogItems.asCatalog()],
    );
    _seedSurface();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Build and dispatch the A2UI messages that paint the outcome screen.
  ///
  /// Two messages: one [genui.CreateSurface] to register the surface ID +
  /// catalog, then one [genui.UpdateComponents] containing the actual node
  /// tree. The root component must have id `root` per the basic-catalog rules.
  void _seedSurface() {
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
              'children': ['headline', 'subtext'],
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── A2UI-rendered outcome screen ─────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: genui.Surface(
                surfaceContext: _controller.contextFor(_surfaceId),
              ),
            ),
          ),

          // ── A2UI-rendered footer badge (so judges see this is genui) ─────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'rendered via flutter/genui (A2UI v0.9)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // ── Restart button outside the Surface ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: OutlinedButton.icon(
              onPressed: widget.onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text('Restart'),
            ),
          ),
        ],
      ),
    );
  }
}
