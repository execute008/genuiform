import 'package:freezed_annotation/freezed_annotation.dart';

import 'num_range.dart';

part 'field_spec.freezed.dart';
part 'field_spec.g.dart';

/// Resolves a [FieldSpec.type] string to its corresponding Dart [Type].
///
/// `Type` objects cannot round-trip through JSON, so [FieldSpec] stores the
/// type as a `String`. Use this map at runtime to recover the concrete type.
const Map<String, Type> kFieldTypeFromString = {
  'String': String,
  'int': int,
  'double': double,
  'bool': bool,
  'DateTime': DateTime,
  'List': List,
  'Enum': Enum,
};

/// The typed specification of a single field in a [Contract].
///
/// [FieldSpec] describes *what* is to be collected for a given field:
/// its type, whether it is required for completion, an optional LLM hint
/// ([description]), and optional validation bounds.
///
/// **[type]** is stored as a `String` (one of `'String'`, `'int'`,
/// `'double'`, `'bool'`, `'DateTime'`, `'List'`, `'Enum'`) because Dart's
/// [Type] object cannot be JSON-serialised. Use [kFieldTypeFromString] to
/// recover the concrete [Type] at runtime.
///
/// **[description]** is prompt fuel — the LLM uses it to understand both
/// what the field means and how to handle user resistance.
///
/// **[exploratoryFields]** never gate completion; only `required: true` fields
/// block the runtime's completion check.
@freezed
abstract class FieldSpec with _$FieldSpec {
  const factory FieldSpec({
    /// The Dart type name. One of: `'String'`, `'int'`, `'double'`,
    /// `'bool'`, `'DateTime'`, `'List'`, `'Enum'`.
    required String type,

    /// Whether this field must be populated for the [Contract] to be
    /// considered complete. The runtime enforces this — the LLM does not.
    required bool required,

    /// Optional hint fed to the LLM describing the field's meaning and how
    /// to handle user resistance. This is prompt fuel, not validation.
    String? description,

    /// For `'String'` or `'Enum'` fields, the set of acceptable values.
    List<dynamic>? enumValues,

    /// For numeric fields, the inclusive min/max bounds.
    @JsonKey(toJson: _numRangeToJson, fromJson: _numRangeFromJson)
    NumRange? range,

    /// Minimum character/element length for `'String'` or `'List'` fields.
    int? minLength,

    /// Maximum character/element length for `'String'` or `'List'` fields.
    int? maxLength,
  }) = _FieldSpec;

  factory FieldSpec.fromJson(Map<String, dynamic> json) =>
      _$FieldSpecFromJson(json);
}

Map<String, dynamic>? _numRangeToJson(NumRange? range) => range?.toJson();

NumRange? _numRangeFromJson(Map<String, dynamic>? json) =>
    json != null ? NumRange.fromJson(json) : null;
