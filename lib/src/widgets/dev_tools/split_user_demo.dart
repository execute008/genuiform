import 'package:flutter/material.dart';

import '../../llm/llm_client.dart';
import '../../models/constraints.dart';
import '../../models/contract.dart';
import '../../models/outcomes.dart';
import '../../models/posture.dart';
import '../../strategies/strategy.dart';
import '../genui_form.dart';

/// Renders two [GenuiForm] instances side-by-side in a [Row].
///
/// [SplitUserDemo] is the hackathon killer demo widget from spec §13.2 and
/// §14. It runs two completely independent form sessions — one fed by
/// [leftClient] (simulating an engaged user) and one by [rightClient]
/// (simulating a tired or terse user) — with identical [contract],
/// [constraints], [posture], and [outcomes]. The divergence in LLM responses
/// drives visibly different conversation depths.
///
/// ### Typical usage
///
/// ```dart
/// SplitUserDemo(
///   contract: leadContract,
///   constraints: leadConstraints,
///   posture: Posture.salesDiscovery(),
///   outcomes: leadOutcomes,
///   leftClient: engagedUserScript,
///   rightClient: tiredUserScript,
///   model: 'gemini-2.5-flash',
/// )
/// ```
///
/// Both [GenuiForm]s are independent — their [FormController]s do not share
/// state. Use `find.byType(GenuiForm)` to locate both in widget tests.
class SplitUserDemo extends StatelessWidget {
  /// Creates a [SplitUserDemo].
  const SplitUserDemo({
    required this.contract,
    required this.constraints,
    required this.posture,
    required this.outcomes,
    required this.leftClient,
    required this.rightClient,
    required this.model,
    this.leftLabel = 'Engaged user',
    this.rightLabel = 'Tired user',
    this.leftStrategy,
    this.rightStrategy,
    super.key,
  });

  /// The fields both forms must collect.
  final Contract contract;

  /// Hard invariants enforced in both sessions.
  final List<Constraint> constraints;

  /// Soft behavioural posture used by both forms.
  final Posture posture;

  /// The shared outcome tree.
  final OutcomeNode outcomes;

  /// LLM client for the left (engaged-user) form — typically a [FakeLlmClient]
  /// with a long-answer script in tests.
  final LlmClient leftClient;

  /// LLM client for the right (tired-user) form — typically a [FakeLlmClient]
  /// with terse-answer script in tests.
  final LlmClient rightClient;

  /// The Vertex AI model ID string (e.g. `'gemini-2.5-flash'`).
  final String model;

  /// Display label for the left column. Defaults to `'Engaged user'`.
  final String leftLabel;

  /// Display label for the right column. Defaults to `'Tired user'`.
  final String rightLabel;

  /// Optional strategy override for the left form.
  final Strategy? leftStrategy;

  /// Optional strategy override for the right form.
  final Strategy? rightStrategy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: engaged user ───────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ColumnHeader(label: leftLabel, color: Colors.green.shade700),
              Expanded(
                child: GenuiForm(
                  contract: contract,
                  constraints: constraints,
                  posture: posture,
                  outcomes: outcomes,
                  client: leftClient,
                  model: model,
                  strategy: leftStrategy,
                ),
              ),
            ],
          ),
        ),

        // ── Divider ──────────────────────────────────────────────────────────
        const VerticalDivider(width: 1),

        // ── Right: tired user ────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ColumnHeader(label: rightLabel, color: Colors.orange.shade700),
              Expanded(
                child: GenuiForm(
                  contract: contract,
                  constraints: constraints,
                  posture: posture,
                  outcomes: outcomes,
                  client: rightClient,
                  model: model,
                  strategy: rightStrategy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Column header ──────────────────────────────────────────────────────────────

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
