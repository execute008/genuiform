// Pure Dart — no Flutter imports.

import '../models/contract.dart';
import '../models/outcomes.dart';
import '../models/session.dart';

// ────────────────────────────────────────────────────────────────────────────
// OutcomeNavigator
// ────────────────────────────────────────────────────────────────────────────

/// Walks the [OutcomeNode] tree, computes the running contract from the
/// chosen path, and advances the session through the tree.
///
/// [OutcomeNavigator] is a pure query object — it reads from [Session] and
/// the tree rooted at [root] but never mutates either. The Strategy or
/// FormController is responsible for creating the new [Session] after advance.
class OutcomeNavigator {
  /// Creates a navigator rooted at [root].
  ///
  /// The [root] must be the top of the outcome tree configured for the form.
  OutcomeNavigator(this._root);

  final OutcomeNode _root;

  // ── Running contract ──────────────────────────────────────────────────────

  /// Computes the running [Contract] for the current path through the tree.
  ///
  /// This is a thin wrapper around [Session.composeRunningContract] that reads
  /// `chosenBranchOptions` from `session.answers['__branch_choices']`
  /// (a `Map<String, String>?`). If the key is absent, an empty map is used
  /// (no branch choices recorded yet).
  Contract runningContract(Session session) {
    final raw = session.answers['__branch_choices'];
    final Map<String, String> chosenBranchOptions;

    if (raw is Map) {
      chosenBranchOptions = Map<String, String>.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    } else {
      chosenBranchOptions = const {};
    }

    return Session.composeRunningContract(
      root: _root,
      currentNode: session.currentNode,
      chosenBranchOptions: chosenBranchOptions,
    );
  }

  // ── Layer completion ──────────────────────────────────────────────────────

  /// Returns `true` when every `required` field in the cumulative contract
  /// up to and including [layer] has a non-null value in [session.answers].
  ///
  /// "Cumulative contract up to and including [layer]" means the merge of all
  /// [contractDelta]s on the path from [_root] to [layer], inclusive. This is
  /// computed by [Session.composeRunningContract] using [layer] as the
  /// current node.
  ///
  /// Branch choices are read from `session.answers['__branch_choices']` in the
  /// same way as [runningContract].
  bool isLayerComplete(Layer layer, Session session) {
    final raw = session.answers['__branch_choices'];
    final Map<String, String> chosenBranchOptions;

    if (raw is Map) {
      chosenBranchOptions = Map<String, String>.fromEntries(
        raw.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
      );
    } else {
      chosenBranchOptions = const {};
    }

    final contract = Session.composeRunningContract(
      root: _root,
      currentNode: layer,
      chosenBranchOptions: chosenBranchOptions,
    );

    return _allRequiredPresent(contract, session);
  }

  // ── Tree navigation ───────────────────────────────────────────────────────

  /// Advances from [session.currentNode] to the next node in the tree.
  ///
  /// Rules by node type:
  /// - **[Layer] with `next != null`**: returns `next`.
  /// - **[Layer] with `next == null`**: returns `null` (terminal layer).
  /// - **[Branch]**: requires [chosenBranchOption]; throws [StateError] if
  ///   absent. Returns the matching [BranchOption.child], or throws
  ///   [StateError] if no option with that ID exists.
  /// - **[Outcome]**: always returns `null` (terminal node).
  OutcomeNode? advance(Session session, {String? chosenBranchOption}) {
    return switch (session.currentNode) {
      Layer(:final next) => next,

      Branch(:final id, :final options) => () {
          if (chosenBranchOption == null) {
            throw StateError(
              'advance() called on Branch "$id" without a chosenBranchOption. '
              'Pass the chosen option ID to resolve the branch.',
            );
          }
          final option = options.where((o) => o.id == chosenBranchOption).firstOrNull;
          if (option == null) {
            throw StateError(
              'Unknown branch option: $chosenBranchOption '
              '(branch "$id" has options: ${options.map((o) => o.id).join(', ')})',
            );
          }
          return option.child;
        }(),

      Outcome() => null,
    };
  }

  // ── Completion check ──────────────────────────────────────────────────────

  /// Returns `true` when [session.currentNode] is an [Outcome] AND every
  /// `required` field in [runningContract] has a non-null value in
  /// [session.answers].
  ///
  /// This is the definitive completion signal — the LLM cannot override it.
  bool isComplete(Session session) {
    if (session.currentNode is! Outcome) return false;
    final contract = runningContract(session);
    return _allRequiredPresent(contract, session);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Returns `true` when every `required: true` field in [contract] has a
  /// non-null entry in [session.answers].
  bool _allRequiredPresent(Contract contract, Session session) {
    for (final entry in contract.fields.entries) {
      final spec = entry.value;
      if (spec.required && session.answers[entry.key] == null) {
        return false;
      }
    }
    return true;
  }
}
