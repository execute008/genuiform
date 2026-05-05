import 'package:json_annotation/json_annotation.dart';

/// The LLM's reading of user engagement from the most recent answer.
///
/// Computed by the LLM every turn and returned in the `engagement` field of
/// the `responseSchema`. Combined with [Posture.pacing] to decide whether to
/// continue deeper through the outcome tree or offer a [Layer] exit.
///
/// Wire values (spec §10.2): `"strong"`, `"weak"`, `"negative"`.
@JsonEnum(valueField: 'wireValue')
enum EngagementSignal {
  /// Long answers, momentum, expressed enthusiasm, follow-up questions from
  /// the user. High-pacing forms deepen the tree on this signal.
  @JsonValue('strong')
  strong('strong'),

  /// Short answers, "idk", hedging, deflection. Mid-pacing forms pause at
  /// the current [Layer] on this signal.
  @JsonValue('weak')
  weak('weak'),

  /// Annoyance, explicit fatigue, terse answers after long ones. Any pacing
  /// form offers an exit or ends on this signal.
  @JsonValue('negative')
  negative('negative');

  const EngagementSignal(this.wireValue);

  /// The JSON wire string (matches `responseSchema` enum values exactly).
  final String wireValue;
}

/// Converts an [EngagementSignal] to its JSON wire string.
String engagementSignalToJson(EngagementSignal value) => value.wireValue;

/// Converts a JSON wire string to the corresponding [EngagementSignal].
EngagementSignal engagementSignalFromJson(String value) {
  return EngagementSignal.values.firstWhere(
    (e) => e.wireValue == value,
    orElse: () => throw ArgumentError('Unknown EngagementSignal: $value'),
  );
}
