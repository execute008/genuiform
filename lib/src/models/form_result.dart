import 'package:freezed_annotation/freezed_annotation.dart';

import 'answer.dart';
import 'outcomes.dart';
import 'session_status.dart';

part 'form_result.freezed.dart';
part 'form_result.g.dart';

class _NullableOutcomeConverter
    implements JsonConverter<Outcome?, Map<String, dynamic>?> {
  const _NullableOutcomeConverter();

  @override
  Outcome? fromJson(Map<String, dynamic>? json) =>
      json != null ? OutcomeNode.fromJson(json) as Outcome : null;

  @override
  Map<String, dynamic>? toJson(Outcome? outcome) => outcome?.toJson();
}

/// The final output produced when a form session ends.
///
/// [FormResult] captures everything the session collected, where it ended up
/// ([reachedOutcome]), the full answer history, and the terminal status. It is
/// passed to [Handoff] and [EscalationHandler] callbacks and is also available
/// on [OutcomeReached] events.
///
/// JSON-serialisable for persistence. [reachedOutcome.handoff] is `null` after
/// deserialization; re-attach before use.
@freezed
abstract class FormResult with _$FormResult {
  const factory FormResult({
    /// The flat `fieldId → value` map of everything collected in this session.
    required Map<String, dynamic> collectedFields,

    /// The terminal [Outcome] node reached, or `null` if the session was
    /// abandoned or escalated before completing.
    @_NullableOutcomeConverter() required Outcome? reachedOutcome,

    /// The ordered list of every answer given during the session.
    @JsonKey(toJson: _historyToJson, fromJson: _historyFromJson)
    required List<Answer> history,

    /// The terminal lifecycle state (`completed`, `abandoned`, or `escalated`).
    @JsonKey(toJson: sessionStatusToJson, fromJson: sessionStatusFromJson)
    required SessionStatus status,
  }) = _FormResult;

  factory FormResult.fromJson(Map<String, dynamic> json) =>
      _$FormResultFromJson(json);
}

List<Map<String, dynamic>> _historyToJson(List<Answer> history) =>
    history.map((a) => a.toJson()).toList();

List<Answer> _historyFromJson(List<dynamic> json) => json
    .map((e) => Answer.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();
