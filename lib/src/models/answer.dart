import 'package:freezed_annotation/freezed_annotation.dart';

import 'engagement_signal.dart';
import 'quiz_step_spec.dart';

part 'answer.freezed.dart';
part 'answer.g.dart';

/// A single captured response in a [Session], pairing the step that was
/// shown with the value the user provided.
///
/// [answer] is typed as `dynamic` to accommodate all [QuizInputType]
/// variants: a `text` answer is a `String`, `multiChoice` is a `List<String>`,
/// `number` is a `num`, `date` is an ISO-8601 string, etc.
///
/// Answers are stored immutably in [Session.history] and also indexed by
/// field ID in [Session.answers] for O(1) lookup.
@freezed
abstract class Answer with _$Answer {
  const factory Answer({
    /// The step ID this answer corresponds to. Matches [QuizStepSpec.id].
    required String stepId,

    /// The full spec of the step that was shown, for rendering history.
    @JsonKey(
      toJson: _quizStepSpecToJson,
      fromJson: _quizStepSpecFromJson,
    )
    required QuizStepSpec stepSpec,

    /// The user's response. Type depends on [QuizStepSpec.inputType]:
    /// - `text` → `String`
    /// - `number` / `slider` → `num`
    /// - `date` → `String` (ISO-8601)
    /// - `choice` → `String` (selected choice ID)
    /// - `multiChoice` → `List<String>` (selected choice IDs)
    /// - `noneJustInformation` → `null`
    @JsonKey(includeIfNull: true) dynamic answer,

    /// When the user submitted this answer.
    required DateTime timestamp,

    /// The LLM's engagement reading immediately after seeing this answer.
    @JsonKey(
      toJson: engagementSignalToJson,
      fromJson: engagementSignalFromJson,
    )
    required EngagementSignal engagement,
  }) = _Answer;

  factory Answer.fromJson(Map<String, dynamic> json) =>
      _$AnswerFromJson(json);
}

Map<String, dynamic> _quizStepSpecToJson(QuizStepSpec spec) => spec.toJson();

QuizStepSpec _quizStepSpecFromJson(Map<String, dynamic> json) =>
    QuizStepSpec.fromJson(json);
