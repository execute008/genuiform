/// A named, displayable representation of a handoff action — the example
/// app's lightweight equivalent of the workbench's `SimulatedHandoff`.
///
/// Each terminal `Outcome.id` resolves to a [SimulatedHandoff] in the
/// scenario's `handoffMap`. The page uses [label] for the SnackBar text in
/// the deterministic path, and surfaces both [label] and the session
/// summary to Vertex when emitting an A2UI outcome screen.
class SimulatedHandoff {
  const SimulatedHandoff({required this.label, required this.icon});

  /// Human-readable summary shown in the SnackBar (deterministic mode) and
  /// fed to Vertex as the headline candidate (A2UI mode).
  final String label;

  /// Material icon name (e.g. `'calendar_today'`) used in the SnackBar.
  /// A2UI mode does not consume this — the LLM picks its own icon if any.
  final String icon;

  @override
  String toString() => 'SimulatedHandoff(label: $label, icon: $icon)';
}
