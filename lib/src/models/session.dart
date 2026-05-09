import 'package:freezed_annotation/freezed_annotation.dart';

import 'answer.dart';
import 'contract.dart';
import 'engagement_signal.dart';
import 'outcomes.dart';
import 'session_status.dart';

part 'session.freezed.dart';
part 'session.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// JSON converters for types not handled by default
// ────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _contractToJson(Contract c) => c.toJson();
Contract _contractFromJson(Map<String, dynamic> json) =>
    Contract.fromJson(json);

List<Map<String, dynamic>> _historyToJson(List<Answer> history) =>
    history.map((a) => a.toJson()).toList();

List<Answer> _historyFromJson(List<dynamic> json) => json
    .map((e) => Answer.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();

class _OutcomeNodeConverter
    implements JsonConverter<OutcomeNode, Map<String, dynamic>> {
  const _OutcomeNodeConverter();

  @override
  OutcomeNode fromJson(Map<String, dynamic> json) =>
      OutcomeNode.fromJson(json);

  @override
  Map<String, dynamic> toJson(OutcomeNode node) => node.toJson();
}

class _NullableOutcomeConverter
    implements JsonConverter<Outcome?, Map<String, dynamic>?> {
  const _NullableOutcomeConverter();

  @override
  Outcome? fromJson(Map<String, dynamic>? json) =>
      json != null ? OutcomeNode.fromJson(json) as Outcome : null;

  @override
  Map<String, dynamic>? toJson(Outcome? outcome) => outcome?.toJson();
}

// ────────────────────────────────────────────────────────────────────────────
// Session
// ────────────────────────────────────────────────────────────────────────────

/// The immutable state of a form conversation at a single point in time.
///
/// Each turn produces a **new** [Session] — sessions are never mutated.
/// Sessions are JSON-serialisable for resume support; re-attach [Handoff]
/// functions to the outcome tree nodes after deserialization.
///
/// ### Key fields
///
/// - **[currentNode]**: where in the outcome tree the form is right now.
/// - **[history]**: every [Answer] the user has given, in order.
/// - **[answers]**: flat `fieldId → value` lookup for O(1) contract checking.
/// - **[runningContract]**: the merged [Contract] from root → [currentNode].
/// - **[status]**: current lifecycle state.
/// - **[lastSignal]**: the LLM's engagement reading from the most recent turn.
/// - **[reachedOutcome]**: non-null once [status] is [SessionStatus.completed].
@freezed
abstract class Session with _$Session {
  const Session._();

  const factory Session({
    /// Current position in the outcome tree.
    @_OutcomeNodeConverter() required OutcomeNode currentNode,

    /// Ordered history of all answers given in this session.
    @JsonKey(toJson: _historyToJson, fromJson: _historyFromJson)
    required List<Answer> history,

    /// Flat `fieldId → value` map for fast contract-completion checks.
    required Map<String, dynamic> answers,

    /// The merged contract for all nodes on the root → [currentNode] path.
    @JsonKey(toJson: _contractToJson, fromJson: _contractFromJson)
    required Contract runningContract,

    /// Current lifecycle state.
    @JsonKey(toJson: sessionStatusToJson, fromJson: sessionStatusFromJson)
    required SessionStatus status,

    /// The LLM's engagement reading from the most recent answer.
    @JsonKey(
      toJson: engagementSignalToJson,
      fromJson: engagementSignalFromJson,
    )
    required EngagementSignal lastSignal,

    /// The terminal [Outcome] reached; non-null only when
    /// [status] is [SessionStatus.completed].
    @_NullableOutcomeConverter() Outcome? reachedOutcome,

    /// ID of the [Layer] whose exit was just offered to the user.
    ///
    /// Set when the LLM emits `offer_exit` for a layer. Cleared once the user
    /// responds (accepted → `complete`; declined → next `ask_step`). The
    /// [PromptBuilder] surfaces this as `pending_exit_layer` in `[CONTEXT]`
    /// so the LLM knows to emit `complete` (not re-offer) on acceptance.
    String? pendingExitLayerId,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  // ── Static helper ─────────────────────────────────────────────────────────

  /// Computes the running [Contract] for the path from [root] to
  /// [currentNode], merging every node's [contractDelta] (and any chosen
  /// [BranchOption]'s delta) in root-to-target order.
  ///
  /// ### Parameters
  ///
  /// - [root]: the root of the outcome tree.
  /// - [currentNode]: the node the session is currently at. Must be reachable
  ///   from [root]; throws [StateError] otherwise.
  /// - [chosenBranchOptions]: a map from branch ID to the chosen option ID.
  ///   Required for any [Branch] node on the path so the correct option's
  ///   [contractDelta] is included.
  ///
  /// ### Contract composition rule
  ///
  /// - [Layer]: its `contractDelta` is always included when traversed.
  /// - [Branch]: the *chosen* [BranchOption]'s `contractDelta` is included
  ///   (if non-null); the branch itself has no delta.
  /// - [Outcome]: its `contractDelta` is included when reached.
  static Contract composeRunningContract({
    required OutcomeNode root,
    required OutcomeNode currentNode,
    Map<String, String> chosenBranchOptions = const {},
  }) {
    final path = root.pathTo(currentNode.id);

    var running = Contract(fields: {});
    for (final node in path) {
      switch (node) {
        case Layer(contractDelta: final delta):
          running = running.merge(delta);
        case Branch(id: final branchId, options: final options):
          final chosenId = chosenBranchOptions[branchId];
          if (chosenId != null) {
            final chosen = options.where((o) => o.id == chosenId).firstOrNull;
            if (chosen?.contractDelta != null) {
              running = running.merge(chosen!.contractDelta!);
            }
          }
        case Outcome(contractDelta: final delta):
          running = running.merge(delta);
      }
    }
    return running;
  }
}
