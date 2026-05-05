import 'package:freezed_annotation/freezed_annotation.dart';

part 'num_range.freezed.dart';
part 'num_range.g.dart';

/// An inclusive numeric range with optional min and/or max bounds.
///
/// Used by [FieldSpec] to constrain numeric input fields (e.g. `range:
/// NumRange(min: 15, max: 240)` for `workout_minutes`).
/// Both bounds are nullable — omit either to leave that end unbounded.
@freezed
abstract class NumRange with _$NumRange {
  const factory NumRange({
    /// Lower bound (inclusive). Null means no lower bound.
    num? min,

    /// Upper bound (inclusive). Null means no upper bound.
    num? max,
  }) = _NumRange;

  factory NumRange.fromJson(Map<String, dynamic> json) =>
      _$NumRangeFromJson(json);
}
