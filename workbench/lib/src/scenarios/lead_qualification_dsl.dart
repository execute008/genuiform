/// DSL representation of the freelance lead-qualification scenario.
///
/// This string is a Dart-shaped DSL that mirrors the actual config in
/// `example/lib/scenarios/freelance_qualification.dart`. It is displayed
/// verbatim in the left pane for Phase 1. Phase 3 will parse it into real
/// genuiform objects.
const String leadQualificationDsl = r'''
final form = GenuiForm(
  contract: Contract(fields: {
    'name': FieldSpec(type: String, required: true),
    'company': FieldSpec(type: String, required: true),
    'pain_point': FieldSpec(
      type: String,
      required: true,
      description: 'The concrete problem they want solved',
    ),
    'timeline': FieldSpec(
      type: String,
      required: true,
      enumValues: ['immediate', '1-3 months', '3-6 months', '6+'],
    ),
    'budget_eur': FieldSpec(type: int, required: false),
    'role': FieldSpec(
      type: String,
      required: false,
      enumValues: ['decision_maker', 'influencer', 'researcher'],
    ),
  }),
  constraints: [
    NeverCollect('payment_info'),
    NeverCollect('personal_id_numbers'),
    MaxSteps(8),
    EscalateIf('legal threats or hostile language'),
  ],
  posture: Posture.salesDiscovery(),
  outcomes: Branch('lead_split', options: [
    BranchOption('book_call',
      criterion: 'qualified + budget fits + decision-maker',
      child: Outcome('book_call',
        contractDelta: Contract(fields: {}),
        handoff: Handoff(onReached: bookCalendly),
      ),
    ),
    BranchOption('send_proposal',
      criterion: 'qualified + needs more info before commit',
      child: Outcome('send_proposal',
        contractDelta: Contract(fields: {}),
        handoff: Handoff(onReached: emailProposal),
      ),
    ),
    BranchOption('decline',
      criterion: 'budget mismatch, scope mismatch, or red flag',
      child: Outcome('decline',
        contractDelta: Contract(fields: {}),
        handoff: Handoff(onReached: politeDecline),
      ),
    ),
  ]),
);
''';
