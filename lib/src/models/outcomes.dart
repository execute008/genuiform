import 'contract.dart';
import 'handoff.dart';

// ────────────────────────────────────────────────────────────────────────────
// OutcomeNode sealed family
// ────────────────────────────────────────────────────────────────────────────

/// The outcome tree — where the form can end up.
///
/// [OutcomeNode] is a **mixed primitive**: the structure is fixed at
/// configuration time (the consumer writes it in Dart); the routing is soft
/// (the LLM picks which [BranchOption] to follow, guided by [Posture.pacing]
/// and [EngagementSignal]).
///
/// ### Three variants
///
/// - **[Layer]** — a graceful exit point that may continue deeper if
///   engagement is positive (per [Posture.pacing]).
/// - **[Branch]** — an LLM-picked split into one of several [BranchOption]s.
/// - **[Outcome]** — a terminal node; the form ends here.
///
/// ### Contract composition
///
/// Every node on the chosen root → current path contributes its
/// [contractDelta] to the running contract. Use
/// [Session.composeRunningContract] to compute this.
///
/// ### JSON discriminator
///
/// The sealed family uses the `node_type` field as the discriminator:
/// `"Layer"`, `"Branch"`, or `"Outcome"`.
///
/// ### Handoff
///
/// [Layer.handoff] and [Outcome.handoff] are **runtime-only** — not
/// serialised. Re-attach them on session resume.
sealed class OutcomeNode {
  const OutcomeNode();

  /// The stable identifier for this node.
  String get id;

  /// Restores an [OutcomeNode] from its JSON representation.
  ///
  /// The `node_type` field selects the variant. [Handoff] functions are
  /// always `null` after deserialization.
  factory OutcomeNode.fromJson(Map<String, dynamic> json) {
    final nodeType = json['node_type'] as String;
    return switch (nodeType) {
      'Layer' => Layer._fromJson(json),
      'Branch' => Branch._fromJson(json),
      'Outcome' => Outcome._fromJson(json),
      _ => throw ArgumentError('Unknown OutcomeNode node_type: $nodeType'),
    };
  }

  /// Serialises this node to a JSON-compatible map.
  Map<String, dynamic> toJson();

  // ── Tree-walk helpers ────────────────────────────────────────────────────

  /// Returns the DFS pre-order sequence of all nodes in the subtree rooted
  /// at this node (including this node itself).
  Iterable<OutcomeNode> descendants() sync* {
    yield this;
    switch (this) {
      case Layer(next: final next):
        if (next != null) yield* next.descendants();
      case Branch(options: final options):
        for (final opt in options) {
          yield* opt.child.descendants();
        }
      case Outcome():
        // terminal — no children
        break;
    }
  }

  /// Returns the path from this node (root) to the node with [nodeId]
  /// (inclusive on both ends), in root-to-target order.
  ///
  /// Throws [StateError] if no node with [nodeId] exists in this subtree.
  List<OutcomeNode> pathTo(String nodeId) {
    final result = _pathTo(nodeId);
    if (result == null) {
      throw StateError('No OutcomeNode with id "$nodeId" found in the tree.');
    }
    return result;
  }

  List<OutcomeNode>? _pathTo(String nodeId) {
    if (id == nodeId) return [this];
    switch (this) {
      case Layer(next: final next):
        if (next != null) {
          final sub = next._pathTo(nodeId);
          if (sub != null) return [this, ...sub];
        }
      case Branch(options: final options):
        for (final opt in options) {
          final sub = opt.child._pathTo(nodeId);
          if (sub != null) return [this, ...sub];
        }
      case Outcome():
        break;
    }
    return null;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Layer
// ────────────────────────────────────────────────────────────────────────────

/// A graceful exit point in the outcome tree.
///
/// If the form ends here (because engagement is low or the user explicitly
/// exits), [handoff] is called. If engagement is positive (per
/// [Posture.pacing]), the form continues into [next].
///
/// Each [Layer] must produce something immediately useful to the user — not
/// just more data for the product. If it fails this test, consider a [Branch]
/// or remove the layer entirely.
class Layer extends OutcomeNode {
  /// Creates a [Layer] node.
  ///
  /// [handoff] is runtime-only and not serialised.
  Layer({
    required this.id,
    required this.contractDelta,
    required this.handoff,
    this.next,
  });

  @override
  final String id;

  /// The fields this layer adds to the running contract when entered.
  final Contract contractDelta;

  /// Called if the form ends at this layer. **Runtime-only — not serialised.**
  final Handoff? handoff;

  /// The next node in the ladder; `null` if this is the deepest layer.
  final OutcomeNode? next;

  factory Layer._fromJson(Map<String, dynamic> json) {
    return Layer(
      id: json['id'] as String,
      contractDelta: Contract.fromJson(
          Map<String, dynamic>.from(json['contractDelta'] as Map)),
      handoff: null, // runtime-only, not stored in JSON
      next: json['next'] != null
          ? OutcomeNode.fromJson(
              Map<String, dynamic>.from(json['next'] as Map))
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'node_type': 'Layer',
        'id': id,
        'contractDelta': contractDelta.toJson(),
        // handoff intentionally omitted — runtime-only
        if (next != null) 'next': next!.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Layer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          contractDelta == other.contractDelta &&
          next == other.next;

  @override
  int get hashCode => Object.hash(id, contractDelta, next);

  @override
  String toString() =>
      'Layer(id: $id, contractDelta: $contractDelta, next: $next)';
}

// ────────────────────────────────────────────────────────────────────────────
// Branch
// ────────────────────────────────────────────────────────────────────────────

/// An LLM-picked split into one of several [BranchOption]s.
///
/// The LLM evaluates each option's [BranchOption.criterion] against the
/// collected answers and picks exactly one option. The runtime then routes
/// the session into the chosen option's [BranchOption.child].
class Branch extends OutcomeNode {
  Branch({required this.id, required this.options});

  @override
  final String id;

  /// The mutually exclusive paths the LLM may choose from.
  final List<BranchOption> options;

  factory Branch._fromJson(Map<String, dynamic> json) {
    final optionsJson = (json['options'] as List)
        .cast<Map<String, dynamic>>();
    return Branch(
      id: json['id'] as String,
      options: optionsJson.map(BranchOption.fromJson).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'node_type': 'Branch',
        'id': id,
        'options': options.map((o) => o.toJson()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Branch &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _listEquals(options, other.options);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(options));

  @override
  String toString() => 'Branch(id: $id, options: $options)';
}

// ────────────────────────────────────────────────────────────────────────────
// Outcome
// ────────────────────────────────────────────────────────────────────────────

/// A terminal outcome — the form ends here; no further questions are asked.
///
/// [handoff] is called once the contract is satisfied and this outcome is
/// reached (e.g. `bookCalendly`, `emailProposal`, `politeDecline`).
class Outcome extends OutcomeNode {
  /// Creates an [Outcome] node.
  ///
  /// [handoff] is runtime-only and not serialised.
  Outcome({
    required this.id,
    required this.contractDelta,
    required this.handoff,
  });

  @override
  final String id;

  /// The fields this outcome adds to the running contract on completion.
  final Contract contractDelta;

  /// Called when this outcome is reached. **Runtime-only — not serialised.**
  final Handoff? handoff;

  factory Outcome._fromJson(Map<String, dynamic> json) {
    return Outcome(
      id: json['id'] as String,
      contractDelta: Contract.fromJson(
          Map<String, dynamic>.from(json['contractDelta'] as Map)),
      handoff: null, // runtime-only
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'node_type': 'Outcome',
        'id': id,
        'contractDelta': contractDelta.toJson(),
        // handoff intentionally omitted — runtime-only
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Outcome &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          contractDelta == other.contractDelta;

  @override
  int get hashCode => Object.hash(id, contractDelta);

  @override
  String toString() =>
      'Outcome(id: $id, contractDelta: $contractDelta)';
}

// ────────────────────────────────────────────────────────────────────────────
// BranchOption
// ────────────────────────────────────────────────────────────────────────────

/// One option within a [Branch].
///
/// The LLM picks the option whose [criterion] best matches the collected
/// answers. The chosen option's [contractDelta] is merged into the running
/// contract, and the session advances into [child].
///
/// **[contractDelta] is nullable** (Spec v0.4 Fix A): some branches only
/// route without adding fields (e.g. `skip_nutrition`).
class BranchOption {
  const BranchOption({
    required this.id,
    required this.criterion,
    this.contractDelta,
    required this.child,
  });

  /// Stable identifier for this option.
  final String id;

  /// Natural-language rule the LLM uses to decide whether to pick this
  /// option (e.g. `'qualified + budget fits + decision-maker'`).
  final String criterion;

  /// Fields this option adds to the running contract when chosen.
  /// **Nullable** (Spec v0.4 Fix A) — some options only route without adding
  /// extra fields (e.g. `skip_nutrition`).
  final Contract? contractDelta;

  /// The subtree the session enters when this option is chosen.
  final OutcomeNode child;

  /// Deserialises from JSON. Handles the recursive [OutcomeNode] type for
  /// [child] and the nullable [contractDelta] (Spec v0.4 Fix A).
  factory BranchOption.fromJson(Map<String, dynamic> json) {
    return BranchOption(
      id: json['id'] as String,
      criterion: json['criterion'] as String,
      contractDelta: json['contractDelta'] != null
          ? Contract.fromJson(
              Map<String, dynamic>.from(json['contractDelta'] as Map))
          : null,
      child: OutcomeNode.fromJson(
          Map<String, dynamic>.from(json['child'] as Map)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'criterion': criterion,
        if (contractDelta != null) 'contractDelta': contractDelta!.toJson(),
        'child': child.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchOption &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          criterion == other.criterion &&
          contractDelta == other.contractDelta &&
          child == other.child;

  @override
  int get hashCode => Object.hash(id, criterion, contractDelta, child);

  @override
  String toString() =>
      'BranchOption(id: $id, criterion: $criterion, contractDelta: $contractDelta, child: $child)';
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
