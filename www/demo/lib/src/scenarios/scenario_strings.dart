/// All four bundled DSL scenario strings for the workbench.
///
/// These are displayed in the editor pane and parsed on demand.
/// Each string is a valid DSL that the [parseDsl] function can consume.
library;

// ─────────────────────────────────────────────────────────────────────────────
// §6.1  Lead Qualification (the hackathon hero)
// ─────────────────────────────────────────────────────────────────────────────

/// The freelance lead-qualification scenario, per spec §6.1 / §11.1.
///
/// Outcome is a [Branch] with three options:
/// `book_call`, `send_proposal`, `decline`.
const String kLeadQualificationDsl = r'''
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
        handoff: Handoff(label: 'Book a call', icon: 'calendar_today'),
      ),
    ),
    BranchOption('send_proposal',
      criterion: 'qualified + needs more info before commit',
      child: Outcome('send_proposal',
        contractDelta: Contract(fields: {}),
        handoff: Handoff(label: 'Send proposal', icon: 'mail_outline'),
      ),
    ),
    BranchOption('decline',
      criterion: 'budget mismatch, scope mismatch, or red flag',
      child: Outcome('decline',
        contractDelta: Contract(fields: {}),
        handoff: Handoff(label: 'Politely decline', icon: 'logout'),
      ),
    ),
  ]),
);
''';

// ─────────────────────────────────────────────────────────────────────────────
// §6.2  GymGeist Onboarding (the depth-adaptive demo)
// ─────────────────────────────────────────────────────────────────────────────

/// The GymGeist onboarding ladder, per spec §6.2 / §11.2.
///
/// Structure:
///   Layer('account_only')
///     └─ Layer('with_workout_plan')
///          └─ Branch('nutrition_path')
///               ├─ BranchOption('with_meal_plan') → Outcome('full_meal_plan')
///               └─ BranchOption('skip_nutrition') → Outcome('workout_only')
const String kGymgeistOnboardingDsl = r'''
final form = GenuiForm(
  contract: Contract(fields: {
    'email': FieldSpec(type: String, required: true),
    'name': FieldSpec(type: String, required: true),
  }),
  constraints: [
    NeverSkip(['height_cm', 'weight_kg']),
    MaxSteps(10),
    StopIf('user is under 16'),
    EscalateIf('eating disorder or extreme restriction'),
  ],
  posture: Posture.supportiveOnboarding(),
  outcomes: Layer('account_only',
    contractDelta: Contract(fields: {
      'email': FieldSpec(type: String, required: true),
      'name': FieldSpec(type: String, required: true),
    }),
    handoff: Handoff(label: 'Enter app', icon: 'home_outlined'),
    next: Layer('with_workout_plan',
      contractDelta: Contract(fields: {
        'goals': FieldSpec(type: List, required: true),
        'fitness_level': FieldSpec(type: String, required: true),
        'equipment': FieldSpec(type: List, required: true),
        'height_cm': FieldSpec(
          type: int,
          required: true,
          range: NumRange(min: 100, max: 250),
        ),
        'weight_kg': FieldSpec(
          type: int,
          required: true,
          range: NumRange(min: 30, max: 300),
        ),
        'workout_minutes': FieldSpec(
          type: int,
          required: true,
          range: NumRange(min: 15, max: 240),
        ),
      }),
      handoff: Handoff(label: 'Generate workout plan', icon: 'fitness_center'),
      next: Branch('nutrition_path', options: [
        BranchOption('with_meal_plan',
          criterion: 'user wants concrete meals planned',
          contractDelta: Contract(fields: {
            'dietary_restrictions': FieldSpec(
              type: List,
              required: true,
              enumValues: ['vegetarian', 'vegan', 'omnivore', 'keto', 'paleo'],
            ),
            'meals_per_day': FieldSpec(
              type: int,
              required: true,
              range: NumRange(min: 2, max: 6),
            ),
          }),
          child: Outcome('full_meal_plan',
            contractDelta: Contract(fields: {}),
            handoff: Handoff(
              label: 'Generate full setup with meals',
              icon: 'restaurant',
            ),
          ),
        ),
        BranchOption('skip_nutrition',
          criterion: 'user opts out of nutrition entirely',
          child: Outcome('workout_only',
            contractDelta: Contract(fields: {}),
            handoff: Handoff(
              label: 'Workout-only setup',
              icon: 'check_circle_outline',
            ),
          ),
        ),
      ]),
    ),
  ),
);
''';

// ─────────────────────────────────────────────────────────────────────────────
// §6.3  Newsletter Signup (the simple one)
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal two-field newsletter signup, per spec §6.3.
///
/// Two fields, no constraints beyond MaxSteps(3), single Outcome.
const String kNewsletterSignupDsl = r'''
final form = GenuiForm(
  contract: Contract(fields: {
    'email': FieldSpec(type: String, required: true,
      description: 'Email for newsletter delivery'),
    'frequency_preference': FieldSpec(type: String, required: false,
      enumValues: ['daily', 'weekly', 'monthly'],
      description: 'How often the user wants to hear from us'),
  }),
  constraints: [MaxSteps(3)],
  posture: Posture(
    persistence: 1, exploration: 1, pacing: 1, skipTolerance: 5,
    voice: 'Brief, friendly, respectful of the user\'s time.',
  ),
  outcomes: Outcome('subscribed',
    contractDelta: Contract(fields: {}),
    handoff: Handoff(label: 'Enter app', icon: 'home_outlined')),
);
''';

// ─────────────────────────────────────────────────────────────────────────────
// §6.4  Medical Intake (the constraint-heavy one)
// ─────────────────────────────────────────────────────────────────────────────

/// Heavy-constraint clinical intake form, per spec §6.4.
///
/// Demonstrates EscalateIf, StopIf, RequireConsent.
/// Posture: Posture.clinicalIntake().
/// Single Outcome with politeDecline handoff.
const String kMedicalIntakeDsl = r'''
final form = GenuiForm(
  contract: Contract(fields: {
    'symptoms': FieldSpec(
      type: String,
      required: true,
      description: 'Primary symptoms the patient is experiencing',
    ),
    'duration': FieldSpec(
      type: String,
      required: true,
      description: 'How long symptoms have been present',
    ),
    'severity': FieldSpec(
      type: int,
      required: true,
      range: NumRange(min: 1, max: 10),
      description: 'Severity on a scale of 1 to 10',
    ),
    'medications': FieldSpec(
      type: List,
      required: false,
      description: 'Current medications or supplements',
    ),
    'allergies': FieldSpec(
      type: List,
      required: false,
      description: 'Known allergies, especially to medications',
    ),
    'consent_given': FieldSpec(
      type: bool,
      required: true,
      description: 'Explicit consent to collect medical history',
    ),
  }),
  constraints: [
    RequireConsent('medical_history_collection'),
    EscalateIf('mentions of self-harm'),
    StopIf('user revokes consent'),
    MaxSteps(12),
  ],
  posture: Posture.clinicalIntake(),
  outcomes: Outcome('intake_complete',
    contractDelta: Contract(fields: {}),
    handoff: Handoff(label: 'Intake complete', icon: 'medical_services_outlined'),
  ),
);
''';
