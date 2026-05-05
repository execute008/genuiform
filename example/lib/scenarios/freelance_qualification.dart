import 'package:genuiform/genuiform.dart';

// ---------------------------------------------------------------------------
// Freelance lead qualification — spec §11.1
//
// Fields, constraints, posture, and outcome tree are taken verbatim from
// spec §11.1. Divergences from the spec's pseudo-Dart are noted inline.
// ---------------------------------------------------------------------------

/// Builds the freelance lead-qualification [GenuiForm] per spec §11.1.
///
/// The form uses [Posture.salesDiscovery()] and a three-way [Branch]:
/// - `book_call`    — qualified lead, budget and decision-maker confirmed.
/// - `send_proposal` — qualified but needs more information.
/// - `decline`      — budget/scope mismatch or red flag.
///
/// [showFeedback] is invoked by each [Handoff] callback and by the
/// [EscalateIf] escalation handler. Wire it to a [ScaffoldMessenger]
/// snackbar (or a dialog) in the parent widget.
///
/// ### Divergences from spec §11.1 pseudo-Dart
///
/// - `FieldSpec(type: String, ...)` → `FieldSpec(type: 'String', ...)`
///   because [FieldSpec.type] is a `String`, not a [Type] object.
/// - `FieldSpec(type: int, ...)` → `FieldSpec(type: 'int', ...)` — same reason.
/// - `Branch('lead_split', options: [...])` → `Branch(id: 'lead_split', options: [...])`
///   — all [OutcomeNode] constructors use named parameters.
/// - `BranchOption('book_call', criterion: ..., child: ...)` →
///   `BranchOption(id: 'book_call', criterion: ..., child: ...)`.
/// - `Handoff(onReached: fn)` → direct `void Function(dynamic)` closure,
///   because [Handoff] is `typedef Handoff = void Function(dynamic result)`.
/// - `EscalateIf('...', handler: PoliteEnd())` →
///   `EscalateIf(trigger: '...', handler: (result) => showFeedback(...))`.
/// - [Outcome] requires `contractDelta` — passed as `Contract(fields: {})`.
GenuiForm freelanceQualificationForm({
  required LlmClient client,
  required String model,
  required void Function(String message) showFeedback,
}) {
  return GenuiForm(
    // ── Contract ────────────────────────────────────────────────────────────
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

    // ── Constraints ─────────────────────────────────────────────────────────
    constraints: [
      const NeverCollect(fieldOrTopic: 'payment_info'),
      const NeverCollect(fieldOrTopic: 'personal_id_numbers'),
      const MaxSteps(value: 8),
      EscalateIf(
        trigger: 'legal threats or hostile language',
        handler: (result) => showFeedback('Form ended due to escalation.'),
      ),
    ],

    // ── Posture ─────────────────────────────────────────────────────────────
    posture: Posture.salesDiscovery(),

    // ── Outcomes ────────────────────────────────────────────────────────────
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
                showFeedback('Booking a call (mock Calendly link)'),
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
              showFeedback('Email proposal queued for $company');
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
                showFeedback('Politely declined — thanks for your time.'),
          ),
        ),
      ],
    ),

    // ── Client & model ───────────────────────────────────────────────────────
    client: client,
    model: model,

    // ── Lifecycle callbacks ──────────────────────────────────────────────────
    onComplete: (result) {
      // The Outcome.handoff has already fired with the routing-specific message.
      // onComplete can be used here to e.g. pop the navigator.
    },
    onEscalation: (rule) {
      showFeedback('Escalated: ${rule.trigger}');
    },
  );
}
