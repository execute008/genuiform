import 'package:flutter/material.dart';

import '../models/quiz_input_type.dart';
import '../models/quiz_step_spec.dart';
import 'inputs/inputs.dart';

/// Dispatches a [QuizStepSpec] to the correct Phase 6 input widget based on
/// [QuizStepSpec.inputType].
///
/// The exhaustive `switch` over the sealed [QuizInputType] enum provides
/// compile-time safety: adding a new [QuizInputType] value without a
/// corresponding case will cause a Dart analysis warning. Intentionally no
/// `default` branch.
class StepRenderer extends StatelessWidget {
  const StepRenderer({
    required this.spec,
    required this.value,
    required this.onChanged,
    this.onSubmit,
    this.validationMessage,
    super.key,
  });

  /// The step specification from the strategy.
  final QuizStepSpec spec;

  /// The current value for this step's input. Type depends on
  /// [QuizStepSpec.inputType].
  final dynamic value;

  /// Called whenever the user changes the input value.
  final ValueChanged<dynamic> onChanged;

  /// Forwarded to inputs whose primary CTA also acts as the form's submit
  /// (currently only [InfoPanel] for info/consent steps).
  final VoidCallback? onSubmit;

  /// Validation error message to display beneath the input, if any.
  final String? validationMessage;

  @override
  Widget build(BuildContext context) {
    return switch (spec.inputType) {
      QuizInputType.slider => SliderInput(
          spec: spec,
          value: value,
          onChanged: onChanged,
          validationMessage: validationMessage,
        ),
      QuizInputType.choice => ChoiceInput(
          spec: spec,
          value: value,
          onChanged: onChanged,
          validationMessage: validationMessage,
        ),
      QuizInputType.multiChoice => MultiChoiceInput(
          spec: spec,
          value: value,
          onChanged: onChanged,
          validationMessage: validationMessage,
        ),
      QuizInputType.text => TextInput(
          spec: spec,
          value: value,
          onChanged: onChanged,
          validationMessage: validationMessage,
        ),
      QuizInputType.number => NumberInput(
          spec: spec,
          value: value,
          onChanged: onChanged,
          validationMessage: validationMessage,
        ),
      QuizInputType.date => DateInput(
          spec: spec,
          value: value,
          onChanged: onChanged,
          validationMessage: validationMessage,
        ),
      QuizInputType.noneJustInformation => InfoPanel(
          spec: spec,
          value: value,
          onChanged: onChanged,
          onSubmit: onSubmit,
          validationMessage: validationMessage,
        ),
    };
  }
}
