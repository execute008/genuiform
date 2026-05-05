import 'package:freezed_annotation/freezed_annotation.dart';

import 'field_spec.dart';

part 'contract.freezed.dart';
part 'contract.g.dart';

/// The typed function signature of a form — a schema of fields to be
/// populated.
///
/// [Contract] is a **hard primitive**: the runtime checks every `required:
/// true` field for a valid non-null value before declaring the form complete.
/// The LLM has no say in completion; it only keeps asking until the contract
/// is satisfiable.
///
/// ### Contract composition
///
/// The *running contract* at any point in the outcome tree is the merge of
/// every [contractDelta] on the path from the tree root to the current node,
/// including any chosen [BranchOption]'s delta. Use [merge] to fold deltas
/// together.
///
/// ### Exploratory fields
///
/// [exploratoryFields] is the LLM's escape hatch for discoveries that were
/// not predefined. They are typed loosely, populated only when relevant, and
/// never gate completion.
@freezed
abstract class Contract with _$Contract {
  const Contract._();

  const factory Contract({
    /// The typed fields this contract requires. Keys are field IDs; values
    /// describe the type, required-ness, and validation bounds.
    @JsonKey(
      toJson: _fieldSpecMapToJson,
      fromJson: _fieldSpecMapFromJson,
    )
    required Map<String, FieldSpec> fields,

    /// Open-ended discoveries the LLM may store. Typed loosely. Never gate
    /// completion.
    Map<String, dynamic>? exploratoryFields,
  }) = _Contract;

  factory Contract.fromJson(Map<String, dynamic> json) =>
      _$ContractFromJson(json);

  /// Returns a new [Contract] that is the symmetric merge of `this` and
  /// [other].
  ///
  /// Merge rules:
  /// - [fields]: all fields from both; [other] wins on key conflict.
  /// - [exploratoryFields]: all entries from both; [other] wins on key
  ///   conflict. If both are `null`, the result is `null`.
  Contract merge(Contract other) {
    final mergedFields = Map<String, FieldSpec>.of(fields)
      ..addAll(other.fields);

    Map<String, dynamic>? mergedExploratory;
    if (exploratoryFields != null || other.exploratoryFields != null) {
      mergedExploratory = Map<String, dynamic>.of(exploratoryFields ?? {})
        ..addAll(other.exploratoryFields ?? {});
    }

    return Contract(
      fields: mergedFields,
      exploratoryFields: mergedExploratory,
    );
  }
}

Map<String, dynamic> _fieldSpecMapToJson(Map<String, FieldSpec> fields) =>
    fields.map((k, v) => MapEntry(k, v.toJson()));

Map<String, FieldSpec> _fieldSpecMapFromJson(Map<String, dynamic> json) =>
    json.map((k, v) => MapEntry(
          k,
          FieldSpec.fromJson(Map<String, dynamic>.from(v as Map)),
        ));
