/// A named, displayable representation of a handoff action — the value
/// type used by both genuiform_workbench (where each `Handoff(label:,
/// icon:)` in the DSL is parsed into a [SimulatedHandoff]) and the example
/// app (where the ScenarioPage's `handoffMap` carries these directly).
///
/// In the deterministic completion path, [label] is shown in a SnackBar.
/// In the A2UI completion path, [label] is surfaced to Vertex as the
/// candidate headline for the generated outcome screen.
class SimulatedHandoff {
  const SimulatedHandoff({required this.label, required this.icon});

  /// Human-readable summary of the outcome.
  final String label;

  /// Material icon name (e.g. `'calendar_today'`, `'mail_outline'`). The
  /// shared package does not interpret this — consumers map it to an
  /// `IconData` via their own lookup table.
  final String icon;

  @override
  String toString() => 'SimulatedHandoff(label: $label, icon: $icon)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimulatedHandoff && label == other.label && icon == other.icon;

  @override
  int get hashCode => Object.hash(label, icon);
}
