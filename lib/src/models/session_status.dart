import 'package:json_annotation/json_annotation.dart';

/// The lifecycle state of a [Session].
///
/// Sessions are immutable; each turn produces a new session with an updated
/// status. The terminal states are [completed], [abandoned], and [escalated].
@JsonEnum(valueField: 'wireValue')
enum SessionStatus {
  /// The session is running — more steps may be emitted.
  @JsonValue('active')
  active('active'),

  /// All required contract fields have been collected and an [Outcome] was
  /// reached. Terminal.
  @JsonValue('completed')
  completed('completed'),

  /// The session ended without completing the contract — the user exited or
  /// a [StopIf] constraint fired. Terminal.
  @JsonValue('abandoned')
  abandoned('abandoned'),

  /// An [EscalateIf] constraint fired, transferring control to the
  /// [EscalationHandler]. Terminal.
  @JsonValue('escalated')
  escalated('escalated');

  const SessionStatus(this.wireValue);

  /// The JSON wire string.
  final String wireValue;
}

/// Converts a [SessionStatus] to its JSON wire string.
String sessionStatusToJson(SessionStatus value) => value.wireValue;

/// Converts a JSON wire string to the corresponding [SessionStatus].
SessionStatus sessionStatusFromJson(String value) {
  return SessionStatus.values.firstWhere(
    (e) => e.wireValue == value,
    orElse: () => throw ArgumentError('Unknown SessionStatus: $value'),
  );
}
