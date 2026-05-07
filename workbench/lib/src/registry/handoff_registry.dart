/// A named, displayable representation of a handoff action.
///
/// Used by the workbench instead of real Dart closures — since the DSL cannot
/// express arbitrary callback code, each `Handoff(onReached: key)` in the DSL
/// resolves to a [SimulatedHandoff] that the preview pane turns into a toast.
class SimulatedHandoff {
  const SimulatedHandoff({required this.label, required this.icon});

  /// Human-readable label shown in the workbench toast.
  final String label;

  /// Icon name (Material icon or custom name) for the toast.
  final String icon;

  @override
  String toString() => 'SimulatedHandoff(label: $label, icon: $icon)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Registry
// ─────────────────────────────────────────────────────────────────────────────

/// All named handoffs available for use in the workbench DSL.
///
/// When a DSL snippet writes `Handoff(onReached: bookCalendly)`, the builder
/// looks up `'bookCalendly'` here to obtain the [SimulatedHandoff] metadata.
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
