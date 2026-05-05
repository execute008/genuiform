import 'package:freezed_annotation/freezed_annotation.dart';

import 'quiz_choice.dart';
import 'quiz_input_type.dart';

part 'quiz_step_spec.freezed.dart';
part 'quiz_step_spec.g.dart';

/// The JSON-serialisable specification for a single form step, as emitted by
/// the LLM in response to the `responseSchema`.
///
/// [QuizStepSpec] is the boundary between the LLM and the Flutter UI: the
/// generative strategy parses the LLM's JSON into a [QuizStepSpec], and the
/// widgets layer renders it. No Flutter imports here — [QuizChoice.iconName]
/// is a `String?` that the widgets layer resolves via the icon registry.
@freezed
abstract class QuizStepSpec with _$QuizStepSpec {
  const factory QuizStepSpec({
    /// Stable identifier for this step. Used to correlate with [Answer.stepId].
    required String id,

    /// The question or prompt shown to the user.
    required String title,

    /// The UI control type. Must be one of the [QuizInputType] values.
    required QuizInputType inputType,

    /// Optional longer description or sub-heading shown beneath [title].
    String? description,

    /// Pre-populated value shown in the input before the user interacts.
    /// Typed as `dynamic` to accommodate all [QuizInputType] variants.
    @JsonKey(includeIfNull: true) dynamic initialValue,

    /// Renderer-specific configuration map (e.g. `{'min': 1, 'max': 10}` for
    /// a slider). Typed loosely to stay forward-compatible.
    Map<String, dynamic>? configuration,

    /// Validation error message shown when the user's answer is invalid.
    String? validationMessage,

    /// Options for `choice` and `multiChoice` steps. Must be non-null and
    /// non-empty when [inputType] is [QuizInputType.choice] or
    /// [QuizInputType.multiChoice].
    @JsonKey(toJson: _choicesToJson, fromJson: _choicesFromJson)
    List<QuizChoice>? choices,
  }) = _QuizStepSpec;

  factory QuizStepSpec.fromJson(Map<String, dynamic> json) =>
      _$QuizStepSpecFromJson(json);
}

List<Map<String, dynamic>>? _choicesToJson(List<QuizChoice>? choices) =>
    choices?.map((c) => c.toJson()).toList();

List<QuizChoice>? _choicesFromJson(List<dynamic>? json) => json
    ?.map((e) => QuizChoice.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();
