import 'package:genuiform/genuiform.dart';
import 'package:genuiform_a2ui/genuiform_a2ui.dart';

// ---------------------------------------------------------------------------
// Freelance lead qualification — spec §11.1
//
// Fields, constraints, posture, and outcome tree are taken verbatim from
// spec §11.1.
// ---------------------------------------------------------------------------

/// Bundle of primitives a [ScenarioPage] needs to run a scenario:
/// the four core inputs to [GenuiForm] plus a side-table mapping each
/// terminal `Outcome.id` to a [SimulatedHandoff] for SnackBar / A2UI rendering.
typedef ScenarioSpec = ({
  Contract contract,
  List<Constraint> constraints,
  Posture posture,
  OutcomeNode outcomes,
  Map<String, SimulatedHandoff> handoffMap,
});

/// Builds the freelance lead-qualification [ScenarioSpec].
///
/// `Outcome.handoff` callbacks are intentionally `null`. The owning
/// [ScenarioPage] reads `result.reachedOutcome?.id` in `onComplete` and
/// either shows a SnackBar (deterministic mode) or hands off to
/// [A2uiOutcomeRenderer] (A2UI mode).
///
/// [showFeedback] is still used for `EscalateIf.handler` callbacks because
/// escalations terminate before the outcome screen and need their own
/// feedback channel.
ScenarioSpec freelanceQualificationSpec({
  required void Function(String message) showFeedback,
}) {
  return (
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
    constraints: [
      const NeverCollect(fieldOrTopic: 'payment_info'),
      const NeverCollect(fieldOrTopic: 'personal_id_numbers'),
      const MaxSteps(value: 8),
      EscalateIf(
        trigger: 'legal threats or hostile language',
        handler: (result) => showFeedback('Form ended due to escalation.'),
      ),
    ],
    posture: Posture.salesDiscovery(),
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
            handoff: null,
          ),
        ),
        BranchOption(
          id: 'send_proposal',
          criterion: 'qualified + needs more info before commit',
          contractDelta: null,
          child: Outcome(
            id: 'send_proposal',
            contractDelta: Contract(fields: {}),
            handoff: null,
          ),
        ),
        BranchOption(
          id: 'decline',
          criterion: 'budget mismatch, scope mismatch, or red flag',
          contractDelta: null,
          child: Outcome(
            id: 'decline',
            contractDelta: Contract(fields: {}),
            handoff: null,
          ),
        ),
      ],
    ),
    handoffMap: const {
      'book_call': SimulatedHandoff(
        label: 'Book a call (mock Calendly link)',
        icon: 'calendar_today',
      ),
      'send_proposal': SimulatedHandoff(
        label: 'Email proposal queued',
        icon: 'mail_outline',
      ),
      'decline': SimulatedHandoff(
        label: 'Politely declined — thanks for your time',
        icon: 'do_not_disturb',
      ),
    },
  );
}
