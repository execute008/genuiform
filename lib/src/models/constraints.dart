import 'package:freezed_annotation/freezed_annotation.dart';

import 'handoff.dart';

part 'constraints.freezed.dart';
part 'constraints.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// Constraint sealed family
// ────────────────────────────────────────────────────────────────────────────

/// A hard invariant enforced by the runtime every turn, overriding any LLM
/// output that would violate it.
///
/// [Constraint] is a **hard primitive**: the runtime checks every constraint
/// against the LLM-emitted step *before* rendering it, and against each user
/// answer for trigger phrases. Violations override whatever the LLM emitted.
///
/// ### JSON discriminator
///
/// The sealed family uses a `type` field as the discriminator
/// (e.g. `{"type": "MaxSteps", "value": 8}`). Use [constraintToJson] and
/// [Constraint.fromJson] for round-trip serialization on the sealed base type.
///
/// **[EscalateIf.handler]** is runtime-only and not included in JSON — it
/// must be re-attached by the consumer on session resume.
sealed class Constraint {
  const Constraint();

  /// Restores a [Constraint] from its JSON representation.
  factory Constraint.fromJson(Map<String, dynamic> json) =>
      constraintFromJson(json);
}

/// Serialises any [Constraint] to a JSON-compatible map.
Map<String, dynamic> constraintToJson(Constraint constraint) {
  return switch (constraint) {
    NeverCollect() => constraint.toJson(),
    NeverSkip() => constraint.toJson(),
    MaxSteps() => constraint.toJson(),
    MinSteps() => constraint.toJson(),
    WhitelistChoices() => constraint.toJson(),
    EscalateIf() => constraint.toJson(),
    StopIf() => constraint.toJson(),
    RequireConsent() => constraint.toJson(),
  };
}

/// Deserialises a [Constraint] from a JSON map, using the `type` discriminator.
///
/// [EscalateIf.handler] is always `null` after deserialization.
Constraint constraintFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  return switch (type) {
    'NeverCollect' => NeverCollect.fromJson(json),
    'NeverSkip' => NeverSkip.fromJson(json),
    'MaxSteps' => MaxSteps.fromJson(json),
    'MinSteps' => MinSteps.fromJson(json),
    'WhitelistChoices' => WhitelistChoices.fromJson(json),
    'EscalateIf' => EscalateIf.fromJson(json),
    'StopIf' => StopIf.fromJson(json),
    'RequireConsent' => RequireConsent.fromJson(json),
    _ => throw ArgumentError('Unknown Constraint type: $type'),
  };
}

// ────────────────────────────────────────────────────────────────────────────
// Variants
// ────────────────────────────────────────────────────────────────────────────

/// Prevents the LLM from collecting the named field or discussing the named
/// topic. Checked against every LLM-emitted step before rendering.
@freezed
abstract class NeverCollect extends Constraint with _$NeverCollect {
  const factory NeverCollect({
    /// The field ID or topic string the form must never collect or ask about.
    required String fieldOrTopic,

    @Default('NeverCollect') String type,
  }) = _NeverCollect;

  const NeverCollect._() : super();

  factory NeverCollect.fromJson(Map<String, dynamic> json) =>
      _$NeverCollectFromJson(json);
}

/// Prevents the listed fields from being skipped. The LLM must keep asking
/// until these fields are populated.
@freezed
abstract class NeverSkip extends Constraint with _$NeverSkip {
  const factory NeverSkip({
    /// The field IDs that must always be answered.
    required List<String> fieldIds,

    @Default('NeverSkip') String type,
  }) = _NeverSkip;

  const NeverSkip._() : super();

  factory NeverSkip.fromJson(Map<String, dynamic> json) =>
      _$NeverSkipFromJson(json);
}

/// Caps the total number of steps the form may emit.
@freezed
abstract class MaxSteps extends Constraint with _$MaxSteps {
  const factory MaxSteps({
    /// The maximum number of steps allowed in this session.
    required int value,

    @Default('MaxSteps') String type,
  }) = _MaxSteps;

  const MaxSteps._() : super();

  factory MaxSteps.fromJson(Map<String, dynamic> json) =>
      _$MaxStepsFromJson(json);
}

/// Requires at least this many steps before completion is allowed.
@freezed
abstract class MinSteps extends Constraint with _$MinSteps {
  const factory MinSteps({
    /// The minimum number of steps before the form may complete.
    required int value,

    @Default('MinSteps') String type,
  }) = _MinSteps;

  const MinSteps._() : super();

  factory MinSteps.fromJson(Map<String, dynamic> json) =>
      _$MinStepsFromJson(json);
}

/// Restricts the LLM to a set of pre-approved values for a given field.
@freezed
abstract class WhitelistChoices extends Constraint with _$WhitelistChoices {
  const factory WhitelistChoices({
    /// The field this whitelist applies to.
    required String fieldId,

    /// The only values the LLM is permitted to offer for [fieldId].
    required List<dynamic> allowed,

    @Default('WhitelistChoices') String type,
  }) = _WhitelistChoices;

  const WhitelistChoices._() : super();

  factory WhitelistChoices.fromJson(Map<String, dynamic> json) =>
      _$WhitelistChoicesFromJson(json);
}

/// Fires [handler] when the user's answer matches [trigger].
///
/// [handler] is **runtime-only** and is not serialised.
class EscalateIf extends Constraint {
  EscalateIf({
    required this.trigger,
    this.handler,
  });

  /// Natural-language description of the condition that triggers escalation.
  final String trigger;

  /// The function to call when the trigger fires.
  ///
  /// **Runtime-only — not serialised.** Will be `null` after deserialization.
  final EscalationHandler? handler;

  factory EscalateIf.fromJson(Map<String, dynamic> json) =>
      EscalateIf(trigger: json['trigger'] as String);

  Map<String, dynamic> toJson() => {
        'type': 'EscalateIf',
        'trigger': trigger,
        // handler intentionally omitted — runtime-only
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EscalateIf &&
          runtimeType == other.runtimeType &&
          trigger == other.trigger;

  @override
  int get hashCode => trigger.hashCode;

  @override
  String toString() => 'EscalateIf(trigger: $trigger)';
}

/// Stops the form entirely when the user's answer matches [trigger].
@freezed
abstract class StopIf extends Constraint with _$StopIf {
  const factory StopIf({
    /// The natural-language condition that halts the form.
    required String trigger,

    @Default('StopIf') String type,
  }) = _StopIf;

  const StopIf._() : super();

  factory StopIf.fromJson(Map<String, dynamic> json) =>
      _$StopIfFromJson(json);
}

/// Requires the user to explicitly consent to the named topic.
@freezed
abstract class RequireConsent extends Constraint with _$RequireConsent {
  const factory RequireConsent({
    /// The topic the user must consent to.
    required String topic,

    @Default('RequireConsent') String type,
  }) = _RequireConsent;

  const RequireConsent._() : super();

  factory RequireConsent.fromJson(Map<String, dynamic> json) =>
      _$RequireConsentFromJson(json);
}
