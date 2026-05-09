import 'package:genuiform/genuiform.dart';

import '../registry/handoff_registry.dart';
import 'ast.dart';
import 'parse_error.dart';

/// The result of translating a [FormNode] AST into real genuiform objects.
///
/// The four primitives are exposed individually so the workbench can wrap
/// them into a [GenuiForm] at render time with the real [LlmClient]. They
/// are non-null on success; all four are null when the AST cannot be
/// translated at all (currently impossible — the builder always produces
/// values, soft errors land in [errors] instead).
class BuildResult {
  const BuildResult({
    this.contract,
    this.constraints,
    this.posture,
    this.outcomes,
    this.handoffMap,
    required this.errors,
  });

  final Contract? contract;
  final List<Constraint>? constraints;
  final Posture? posture;
  final OutcomeNode? outcomes;

  /// Side-table mapping each [Outcome.id] in the parsed tree to its
  /// [SimulatedHandoff] entry (when the registry key resolved successfully).
  /// Used by FormPreview to show a handoff toast on [GenuiForm.onComplete].
  final Map<String, SimulatedHandoff>? handoffMap;

  /// Soft errors encountered during building (e.g. unknown handoff key).
  /// The four primitives may still be present; the form simply has a
  /// `null` handoff for the offending node.
  final List<ParseError> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// Translates a [FormNode] AST into real genuiform types.
///
/// Errors are accumulated rather than thrown, so the builder produces as much
/// as possible even when some references cannot be resolved (e.g. unknown
/// handoff registry keys).
class DslBuilder {
  final List<ParseError> _errors = [];

  /// Maps each [Outcome.id] (terminal node) to its [SimulatedHandoff] entry,
  /// populated during the outcome tree walk. Used by the workbench to display
  /// a handoff toast when [GenuiForm.onComplete] fires.
  final Map<String, SimulatedHandoff> _handoffMap = {};

  BuildResult build(FormNode ast) {
    _errors.clear();
    _handoffMap.clear();

    final contract = _buildContract(ast.contract);
    final constraints = _buildConstraints(ast.constraints);
    final posture = _buildPosture(ast.posture);
    final outcomes = _buildOutcomeNode(ast.outcomes);

    return BuildResult(
      contract: contract,
      constraints: constraints,
      posture: posture,
      outcomes: outcomes,
      handoffMap: Map.unmodifiable(_handoffMap),
      errors: List.unmodifiable(_errors),
    );
  }

  Contract _buildContract(ContractNode node) {
    final fields = <String, FieldSpec>{};
    for (final entry in node.fields.entries) {
      fields[entry.key] = _buildFieldSpec(entry.value);
    }
    return Contract(fields: fields);
  }

  FieldSpec _buildFieldSpec(FieldSpecNode node) {
    return FieldSpec(
      type: node.type,
      required: node.required,
      description: node.description,
      enumValues: node.enumValues,
      range: node.range != null ? _buildNumRange(node.range!) : null,
      minLength: node.minLength,
      maxLength: node.maxLength,
    );
  }

  NumRange _buildNumRange(NumRangeNode node) {
    return NumRange(min: node.min, max: node.max);
  }

  List<Constraint> _buildConstraints(List<ConstraintNode> nodes) {
    return nodes.map(_buildConstraint).toList();
  }

  Constraint _buildConstraint(ConstraintNode node) {
    return switch (node) {
      NeverCollectNode() => NeverCollect(fieldOrTopic: node.fieldOrTopic),
      NeverSkipNode() => NeverSkip(fieldIds: node.fieldIds),
      MaxStepsNode() => MaxSteps(value: node.value),
      MinStepsNode() => MinSteps(value: node.value),
      WhitelistChoicesNode() => WhitelistChoices(
          fieldId: node.fieldId,
          allowed: node.allowed,
        ),
      EscalateIfNode() => EscalateIf(
          trigger: node.trigger,
          handler: null,
        ),
      StopIfNode() => StopIf(trigger: node.trigger),
      RequireConsentNode() => RequireConsent(topic: node.topic),
    };
  }

  Posture _buildPosture(PostureNode node) {
    return switch (node) {
      PosturePresetNode() => _buildPosturePreset(node),
      PostureLiteralNode() => Posture(
          persistence: node.persistence,
          exploration: node.exploration,
          pacing: node.pacing,
          skipTolerance: node.skipTolerance,
          voice: node.voice,
        ),
    };
  }

  Posture _buildPosturePreset(PosturePresetNode node) {
    return switch (node.preset) {
      'salesDiscovery' => Posture.salesDiscovery(),
      'supportiveOnboarding' => Posture.supportiveOnboarding(),
      'clinicalIntake' => Posture.clinicalIntake(),
      _ => throw ParseError(
          line: node.line,
          column: node.column,
          message: "Unknown Posture preset '${node.preset}'",
          hint: 'Valid presets: salesDiscovery, supportiveOnboarding, clinicalIntake',
        ),
    };
  }

  OutcomeNode _buildOutcomeNode(OutcomeAstNode node) {
    return switch (node) {
      LayerAstNode() => _buildLayer(node),
      BranchAstNode() => _buildBranch(node),
      OutcomeTerminalNode() => _buildOutcomeTerminal(node),
    };
  }

  Layer _buildLayer(LayerAstNode node) {
    return Layer(
      id: node.id,
      contractDelta: _buildContract(node.contractDelta),
      handoff: node.handoff != null ? _stubHandoff() : null,
      next: node.next != null ? _buildOutcomeNode(node.next!) : null,
    );
  }

  Branch _buildBranch(BranchAstNode node) {
    return Branch(
      id: node.id,
      options: node.options.map(_buildBranchOption).toList(),
    );
  }

  BranchOption _buildBranchOption(BranchOptionAstNode node) {
    return BranchOption(
      id: node.id,
      criterion: node.criterion,
      contractDelta:
          node.contractDelta != null ? _buildContract(node.contractDelta!) : null,
      child: _buildOutcomeNode(node.child),
    );
  }

  Outcome _buildOutcomeTerminal(OutcomeTerminalNode node) {
    if (node.handoff != null) {
      _registerHandoff(node.id, node.handoff!);
    }
    return Outcome(
      id: node.id,
      contractDelta: _buildContract(node.contractDelta),
      handoff: node.handoff != null ? _stubHandoff() : null,
    );
  }

  /// Records the inline [SimulatedHandoff] for [outcomeId] in the side-table.
  void _registerHandoff(String outcomeId, HandoffStubNode node) {
    _handoffMap[outcomeId] = SimulatedHandoff(
      label: node.label,
      icon: node.icon ?? 'flag',
    );
  }

  /// The closure is a no-op — the workbench uses the side-table for toasts.
  Handoff _stubHandoff() => (_) {};
}
