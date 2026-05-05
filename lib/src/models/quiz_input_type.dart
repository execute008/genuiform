import 'package:json_annotation/json_annotation.dart';

/// The UI control type for a [QuizStepSpec].
///
/// Values serialise with the exact wire strings from spec §10.1 so that the
/// LLM's JSON response and the Dart model stay in lockstep.
///
/// The LLM must only emit values from this enum — the generative strategy
/// rejects any unknown `inputType` string.
@JsonEnum(valueField: 'wireValue')
enum QuizInputType {
  /// A numeric range slider.
  @JsonValue('slider')
  slider('slider'),

  /// A single-select choice list.
  @JsonValue('choice')
  choice('choice'),

  /// A multi-select choice list.
  @JsonValue('multiChoice')
  multiChoice('multiChoice'),

  /// A free-text input.
  @JsonValue('text')
  text('text'),

  /// A numeric input.
  @JsonValue('number')
  number('number'),

  /// A date picker.
  @JsonValue('date')
  date('date'),

  /// An informational display — no input collected for this step.
  @JsonValue('noneJustInformation')
  noneJustInformation('noneJustInformation');

  const QuizInputType(this.wireValue);

  /// The JSON wire string for this value (matches spec §10.1 exactly).
  final String wireValue;
}

/// Converts a [QuizInputType] to its JSON wire string.
String quizInputTypeToJson(QuizInputType value) => value.wireValue;

/// Converts a JSON wire string to the corresponding [QuizInputType].
///
/// Throws [ArgumentError] if the string is not a known value.
QuizInputType quizInputTypeFromJson(String value) {
  return QuizInputType.values.firstWhere(
    (e) => e.wireValue == value,
    orElse: () => throw ArgumentError('Unknown QuizInputType: $value'),
  );
}
