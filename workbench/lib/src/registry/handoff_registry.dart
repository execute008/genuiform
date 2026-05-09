// Workbench handoff registry — the side-table that resolves DSL
// `Handoff(label:, icon:)` literals into a [SimulatedHandoff] for the
// preview pane.
//
// [SimulatedHandoff] itself lives in `package:genuiform_a2ui` so that both
// the workbench and the example app share the same value type. This file
// is a thin re-export plus the workbench-specific named handoff catalog.

export 'package:genuiform_a2ui/genuiform_a2ui.dart' show SimulatedHandoff;

import 'package:genuiform_a2ui/genuiform_a2ui.dart';

/// All named handoffs available for use in the workbench DSL.
///
/// When a DSL snippet writes `Handoff(onReached: bookCalendly)`, the
/// builder looks up `'bookCalendly'` here to obtain the [SimulatedHandoff]
/// metadata.
const Map<String, SimulatedHandoff> kHandoffRegistry = {
  'bookCalendly': SimulatedHandoff(
    label: 'Book a call',
    icon: 'calendar',
  ),
  'emailProposal': SimulatedHandoff(
    label: 'Send proposal',
    icon: 'mail',
  ),
  'politeDecline': SimulatedHandoff(
    label: 'Politely decline',
    icon: 'door',
  ),
  'enterAppMinimal': SimulatedHandoff(
    label: 'Enter app',
    icon: 'home',
  ),
  'generateWorkoutPlan': SimulatedHandoff(
    label: 'Generate workout plan',
    icon: 'dumbbell',
  ),
  'fullSetupMeals': SimulatedHandoff(
    label: 'Generate full setup with meals',
    icon: 'utensils',
  ),
  'fullSetupMacros': SimulatedHandoff(
    label: 'Generate setup with macros',
    icon: 'scale',
  ),
  'workoutOnlySetup': SimulatedHandoff(
    label: 'Workout-only setup',
    icon: 'check',
  ),
};
