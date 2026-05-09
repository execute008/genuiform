import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import 'a2ui/a2ui_outcome_emitter.dart';
import 'a2ui/a2ui_outcome_loader.dart';
import 'a2ui/a2ui_outcome_renderer.dart';
import 'a2ui/simulated_handoff.dart';
import 'scenarios/freelance_qualification.dart' show ScenarioSpec;

/// Hosts a [GenuiForm] built from a [ScenarioSpec] and routes form
/// completion to either a SnackBar (deterministic mode) or a live
/// A2UI-rendered outcome screen ([A2uiOutcomeRenderer]).
///
/// Re-keying the inner form (via [_formKey]) cleanly resets the
/// [FormController] and triggers a fresh session when the user taps Restart.
class ScenarioPage extends StatefulWidget {
  const ScenarioPage({
    required this.title,
    required this.spec,
    required this.client,
    required this.model,
    required this.useA2ui,
    this.emitter,
    super.key,
  });

  final String title;
  final ScenarioSpec spec;
  final LlmClient client;
  final String model;

  /// When true, completion swaps the form pane for [A2uiOutcomeRenderer]
  /// streaming a Vertex-emitted A2UI tree (with hand-crafted fallback).
  final bool useA2ui;

  /// Optional emitter used when [useA2ui] is true. When null (or when the
  /// emitter errors / times out), the renderer falls back to its
  /// hand-crafted v1 tree so the user always sees an outcome screen.
  final A2uiOutcomeEmitter? emitter;

  @override
  State<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends State<ScenarioPage> {
  /// Bumped on Restart to force a clean [FormController] tear-down + rebuild.
  int _formKey = 0;

  /// When set, the A2UI outcome renderer replaces the form pane.
  ({
    String outcomeId,
    SimulatedHandoff? handoff,
    Stream<String>? a2uiStream,
  })? _activeA2uiHandoff;

  void _showSnackBar(String message, {IconData icon = Icons.info_outline}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _handleComplete(FormResult result) {
    if (!mounted) return;
    final outcomeId = result.reachedOutcome?.id;
    if (outcomeId == null) return;

    final handoff = widget.spec.handoffMap[outcomeId];

    if (widget.useA2ui) {
      Stream<String>? a2uiStream;
      if (widget.emitter != null) {
        final loader = A2uiOutcomeLoader(emitter: widget.emitter!);
        a2uiStream = loader.load(
          outcomeId: outcomeId,
          handoff: handoff,
          result: result,
        );
      }
      // emitter == null → renderer falls back to v1 hand-crafted tree.
      setState(() {
        _activeA2uiHandoff = (
          outcomeId: outcomeId,
          handoff: handoff,
          a2uiStream: a2uiStream,
        );
      });
      return;
    }

    final label = handoff?.label ?? 'Form completed — outcome: $outcomeId';
    _showSnackBar(label, icon: Icons.check_circle_outline);
  }

  void _restart() {
    setState(() {
      _activeA2uiHandoff = null;
      _formKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _activeA2uiHandoff != null
        ? A2uiOutcomeRenderer(
            outcomeId: _activeA2uiHandoff!.outcomeId,
            handoff: _activeA2uiHandoff!.handoff,
            onRestart: _restart,
            a2uiMessageStream: _activeA2uiHandoff!.a2uiStream,
          )
        : GenuiForm(
            key: ValueKey(_formKey),
            contract: widget.spec.contract,
            constraints: widget.spec.constraints,
            posture: widget.spec.posture,
            outcomes: widget.spec.outcomes,
            client: widget.client,
            model: widget.model,
            onComplete: _handleComplete,
            onEscalation: (rule) => _showSnackBar(
              'Escalated: ${rule.trigger}',
              icon: Icons.warning_amber_rounded,
            ),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.useA2ui)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  label: Text('A2UI'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: body,
    );
  }
}
