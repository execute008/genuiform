/// Registry of all bundled workbench scenario presets.
library;

import 'scenario.dart';
import 'scenario_strings.dart';

export 'scenario.dart';

/// All four bundled scenarios, in display order.
const List<Scenario> kScenarios = [
  Scenario(
    id: 'lead_qualification',
    name: 'Lead qualification',
    description: 'Branching freelance lead qualification — book / proposal / decline',
    dsl: kLeadQualificationDsl,
  ),
  Scenario(
    id: 'gymgeist_onboarding',
    name: 'GymGeist onboarding',
    description: 'Depth-adaptive fitness onboarding ladder with nutrition branch',
    dsl: kGymgeistOnboardingDsl,
  ),
  Scenario(
    id: 'newsletter_signup',
    name: 'Newsletter signup',
    description: 'Minimal two-field signup — simplest possible form',
    dsl: kNewsletterSignupDsl,
  ),
  Scenario(
    id: 'medical_intake',
    name: 'Medical intake',
    description: 'Constraint-heavy clinical intake — EscalateIf, StopIf, RequireConsent',
    dsl: kMedicalIntakeDsl,
  ),
];

/// Look up a scenario by its [id], returning `null` if not found.
Scenario? scenarioById(String id) =>
    kScenarios.where((s) => s.id == id).firstOrNull;
