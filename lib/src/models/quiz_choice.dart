import 'package:freezed_annotation/freezed_annotation.dart';

part 'quiz_choice.freezed.dart';
part 'quiz_choice.g.dart';

/// A single option within a `choice` or `multiChoice` [QuizStepSpec].
///
/// [iconName] is a `String?` — the LLM emits it as a name string (e.g.
/// `'star'`). Resolution to an `IconData` happens in the widgets layer using
/// the icon registry. This keeps the models layer free of Flutter imports.
@freezed
abstract class QuizChoice with _$QuizChoice {
  const factory QuizChoice({
    /// Stable identifier for this choice. Stored in [Answer.answer] when
    /// selected.
    required String id,

    /// Display label shown to the user.
    required String label,

    /// Optional longer description shown beneath the label.
    String? description,

    /// Icon name string emitted by the LLM (e.g. `'leaf'`, `'star'`).
    /// Resolved to `IconData` by the icon registry in the widgets layer.
    /// No Flutter imports here.
    String? iconName,

    /// When `true`, this choice reveals a free-text input field in addition
    /// to being selectable (e.g. an "Other — specify" option).
    @Default(false) bool isTextField,

    /// Arbitrary key-value pairs for renderer configuration (e.g. accent
    /// colour, image URL). Typed loosely so the schema stays forward-compatible.
    Map<String, dynamic>? configuration,
  }) = _QuizChoice;

  factory QuizChoice.fromJson(Map<String, dynamic> json) =>
      _$QuizChoiceFromJson(json);
}
