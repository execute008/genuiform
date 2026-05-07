import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

/// Returns the hardcoded lead-qualification [GenuiForm] widget.
///
/// The contract, constraints, posture, and outcomes are lifted verbatim from
/// `example/lib/scenarios/freelance_qualification.dart`.
///
/// [client] is the LLM transport. [model] is the Vertex AI model string.
/// [onControllerCreated] is forwarded to [GenuiForm] so an outside widget
/// (e.g. the debug strip) can subscribe to session updates.
Widget leadQualificationForm({
  required LlmClient client,
  required String model,
  void Function(FormController controller)? onControllerCreated,
}) {
  return _LeadQualificationForm(
    client: client,
    model: model,
    onControllerCreated: onControllerCreated,
  );
}

class _LeadQualificationForm extends StatelessWidget {
  const _LeadQualificationForm({
    required this.client,
    required this.model,
    this.onControllerCreated,
  });

  final LlmClient client;
  final String model;
  final void Function(FormController controller)? onControllerCreated;

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return GenuiForm(
      // ── Contract ──────────────────────────────────────────────────────────
      contract: Contract(fields: {
        'name': const FieldSpec(type: 'String', required: true),
        'company': const FieldSpec(type: 'String', required: true),
        'pain_point': const FieldSpec(
          type: 'String',
          required: true,
          description: 'The concrete problem they want solved',
        ),
        'timeline': const FieldSpec(
          type: 'String',
          required: true,
          enumValues: ['immediate', '1-3 months', '3-6 months', '6+'],
        ),
        'budget_eur': const FieldSpec(type: 'int', required: false),
        'role': const FieldSpec(
          type: 'String',
          required: false,
          enumValues: ['decision_maker', 'influencer', 'researcher'],
        ),
      }),

      // ── Constraints ───────────────────────────────────────────────────────
      constraints: [
        const NeverCollect(fieldOrTopic: 'payment_info'),
        const NeverCollect(fieldOrTopic: 'personal_id_numbers'),
        const MaxSteps(value: 8),
        EscalateIf(
          trigger: 'legal threats or hostile language',
          handler: (result) =>
              _showFeedback(context, 'Form ended due to escalation.'),
        ),
      ],

      // ── Posture ───────────────────────────────────────────────────────────
      posture: Posture.salesDiscovery(),

      // ── Outcomes ──────────────────────────────────────────────────────────
      outcomes: Branch(
        id: 'lead_split',
        options: [
          BranchOption(
            id: 'book_call',
            criterion: 'qualified + budget fits + decision-maker',
            contractDelta: null,
            child: Outcome(
              id: 'book_call',
              contractDelta: Contract(fields: {}),
              handoff: (result) =>
                  _showFeedback(context, 'Booking a call (mock Calendly link)'),
            ),
          ),
          BranchOption(
            id: 'send_proposal',
            criterion: 'qualified + needs more info before commit',
            contractDelta: null,
            child: Outcome(
              id: 'send_proposal',
              contractDelta: Contract(fields: {}),
              handoff: (result) {
                final company =
                    (result as dynamic).collectedFields['company'] as String? ??
                        'your company';
                _showFeedback(context, 'Email proposal queued for $company');
              },
            ),
          ),
          BranchOption(
            id: 'decline',
            criterion: 'budget mismatch, scope mismatch, or red flag',
            contractDelta: null,
            child: Outcome(
              id: 'decline',
              contractDelta: Contract(fields: {}),
              handoff: (result) =>
                  _showFeedback(context, 'Politely declined — thanks for your time.'),
            ),
          ),
        ],
      ),

      // ── Client & model ────────────────────────────────────────────────────
      client: client,
      model: model,

      // ── Lifecycle callbacks ───────────────────────────────────────────────
      onControllerCreated: onControllerCreated,
      onEscalation: (rule) {
        _showFeedback(context, 'Escalated: ${rule.trigger}');
      },
    );
  }
}
