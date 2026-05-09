// ─────────────────────────────────────────────────────────────────────────────
// AST node types for the genuiform workbench DSL.
//
// Plain Dart classes — no freezed, no codegen.
// ─────────────────────────────────────────────────────────────────────────────

/// Root form node.
class FormNode {
  FormNode({
    required this.contract,
    required this.constraints,
    required this.posture,
    required this.outcomes,
    required this.line,
    required this.column,
  });

  final ContractNode contract;
  final List<ConstraintNode> constraints;
  final PostureNode posture;
  final OutcomeAstNode outcomes;
  final int line;
  final int column;
}

// ─────────────────────────────────────────────────────────────────────────────
// Contract
// ─────────────────────────────────────────────────────────────────────────────

/// `Contract(fields: { ... })`
class ContractNode {
  ContractNode({required this.fields, required this.line, required this.column});

  final Map<String, FieldSpecNode> fields;
  final int line;
  final int column;
}

/// `FieldSpec(type: String, required: true, ...)`
class FieldSpecNode {
  FieldSpecNode({
    required this.type,
    required this.required,
    this.description,
    this.enumValues,
    this.range,
    this.minLength,
    this.maxLength,
    required this.line,
    required this.column,
  });

  final String type;
  final bool required;
  final String? description;
  final List<dynamic>? enumValues;
  final NumRangeNode? range;
  final int? minLength;
  final int? maxLength;
  final int line;
  final int column;
}

/// `NumRange(min: 15, max: 240)` or `NumRange(15, 240)`
class NumRangeNode {
  NumRangeNode({this.min, this.max, required this.line, required this.column});

  final num? min;
  final num? max;
  final int line;
  final int column;
}

// ─────────────────────────────────────────────────────────────────────────────
// Constraints
// ─────────────────────────────────────────────────────────────────────────────

/// Base class for constraint AST nodes.
sealed class ConstraintNode {
  const ConstraintNode({required this.line, required this.column});

  final int line;
  final int column;
}

class NeverCollectNode extends ConstraintNode {
  const NeverCollectNode({
    required this.fieldOrTopic,
    required super.line,
    required super.column,
  });

  final String fieldOrTopic;
}

class NeverSkipNode extends ConstraintNode {
  const NeverSkipNode({
    required this.fieldIds,
    required super.line,
    required super.column,
  });

  final List<String> fieldIds;
}

class MaxStepsNode extends ConstraintNode {
  const MaxStepsNode({
    required this.value,
    required super.line,
    required super.column,
  });

  final int value;
}

class MinStepsNode extends ConstraintNode {
  const MinStepsNode({
    required this.value,
    required super.line,
    required super.column,
  });

  final int value;
}

class WhitelistChoicesNode extends ConstraintNode {
  const WhitelistChoicesNode({
    required this.fieldId,
    required this.allowed,
    required super.line,
    required super.column,
  });

  final String fieldId;
  final List<dynamic> allowed;
}

class EscalateIfNode extends ConstraintNode {
  const EscalateIfNode({
    required this.trigger,
    required super.line,
    required super.column,
  });

  final String trigger;
}

class StopIfNode extends ConstraintNode {
  const StopIfNode({
    required this.trigger,
    required super.line,
    required super.column,
  });

  final String trigger;
}

class RequireConsentNode extends ConstraintNode {
  const RequireConsentNode({
    required this.topic,
    required super.line,
    required super.column,
  });

  final String topic;
}

// ─────────────────────────────────────────────────────────────────────────────
// Posture
// ─────────────────────────────────────────────────────────────────────────────

sealed class PostureNode {
  const PostureNode({required this.line, required this.column});

  final int line;
  final int column;
}

/// `Posture(persistence: 4, exploration: 2, ...)`
class PostureLiteralNode extends PostureNode {
  const PostureLiteralNode({
    required this.persistence,
    required this.exploration,
    required this.pacing,
    required this.skipTolerance,
    required this.voice,
    required super.line,
    required super.column,
  });

  final int persistence;
  final int exploration;
  final int pacing;
  final int skipTolerance;
  final String voice;
}

/// `Posture.salesDiscovery()` / `Posture.supportiveOnboarding()` / `Posture.clinicalIntake()`
class PosturePresetNode extends PostureNode {
  const PosturePresetNode({
    required this.preset,
    required super.line,
    required super.column,
  });

  /// One of `'salesDiscovery'`, `'supportiveOnboarding'`, `'clinicalIntake'`.
  final String preset;
}

// ─────────────────────────────────────────────────────────────────────────────
// Outcomes
// ─────────────────────────────────────────────────────────────────────────────

sealed class OutcomeAstNode {
  const OutcomeAstNode({required this.id, required this.line, required this.column});

  final String id;
  final int line;
  final int column;
}

/// `Layer('id', contractDelta: ..., next: ..., handoff?: ...)`
class LayerAstNode extends OutcomeAstNode {
  const LayerAstNode({
    required super.id,
    required this.contractDelta,
    required super.line,
    required super.column,
    this.next,
    this.handoff,
  });

  final ContractNode contractDelta;
  final OutcomeAstNode? next;
  final HandoffStubNode? handoff;
}

/// `Branch('id', options: [...])`
class BranchAstNode extends OutcomeAstNode {
  const BranchAstNode({
    required super.id,
    required this.options,
    required super.line,
    required super.column,
  });

  final List<BranchOptionAstNode> options;
}

/// `BranchOption('id', criterion: '...', contractDelta?: ..., child: ...)`
class BranchOptionAstNode {
  const BranchOptionAstNode({
    required this.id,
    required this.criterion,
    required this.child,
    required this.line,
    required this.column,
    this.contractDelta,
  });

  final String id;
  final String criterion;
  final ContractNode? contractDelta;
  final OutcomeAstNode child;
  final int line;
  final int column;
}

/// `Outcome('id', contractDelta: ..., handoff: ...)`
class OutcomeTerminalNode extends OutcomeAstNode {
  const OutcomeTerminalNode({
    required super.id,
    required this.contractDelta,
    required super.line,
    required super.column,
    this.handoff,
  });

  final ContractNode contractDelta;
  final HandoffStubNode? handoff;
}

// ─────────────────────────────────────────────────────────────────────────────
// Handoff stub
// ─────────────────────────────────────────────────────────────────────────────

/// `Handoff(label: '...', icon: '...')` — inline definition of a simulated
/// handoff. The builder turns this directly into a [SimulatedHandoff]; there
/// is no registry indirection.
class HandoffStubNode {
  const HandoffStubNode({
    required this.label,
    this.icon,
    required this.line,
    required this.column,
  });

  final String label;
  final String? icon;
  final int line;
  final int column;
}
