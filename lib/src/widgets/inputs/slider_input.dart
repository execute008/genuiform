import 'package:flutter/material.dart';

import '../../models/quiz_step_spec.dart';
import '_validation_message.dart';

/// A numeric range slider input widget.
///
/// Reads the following keys from [spec.configuration]:
/// - `min` (`num`): minimum value. Required.
/// - `max` (`num`): maximum value. Required.
/// - `step` (`num`): snapping increment (default `1`). The number of slider
///   divisions is derived from `(max - min) / step`.
/// - `unit` (`String?`): optional unit label appended to the displayed value
///   (e.g. `'kg'`, `'min'`).
///
/// [value] is a `num`. Defaults to [spec.initialValue] if provided, otherwise
/// falls back to `min`.
///
/// [onChanged] is called with a `num` value rounded to the nearest [step].
class SliderInput extends StatelessWidget {
  const SliderInput({
    required this.spec,
    required this.value,
    required this.onChanged,
    this.validationMessage,
    super.key,
  });

  final QuizStepSpec spec;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String? validationMessage;

  @override
  Widget build(BuildContext context) {
    final config = spec.configuration ?? {};
    final min = (config['min'] as num? ?? 0).toDouble();
    final max = (config['max'] as num? ?? 100).toDouble();
    final step = (config['step'] as num? ?? 1).toDouble();
    final unit = config['unit'] as String?;

    final rawValue = (value as num? ?? spec.initialValue as num? ?? min).toDouble();
    final currentValue = rawValue.clamp(min, max);

    final divisions = step > 0 ? ((max - min) / step).round() : null;

    final displayValue = _snapToStep(currentValue, min, step);
    final label =
        unit != null ? '${displayValue.toStringAsFixed(_decimals(step))} $unit' : displayValue.toStringAsFixed(_decimals(step));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Slider(
          value: displayValue,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: (newValue) {
            final snapped = _snapToStep(newValue, min, step);
            onChanged(snapped);
          },
        ),
        ValidationMessage(validationMessage),
      ],
    );
  }

  /// Snaps [value] to the nearest [step] increment above [min].
  static double _snapToStep(double value, double min, double step) {
    if (step <= 0) return value;
    final steps = ((value - min) / step).round();
    return min + steps * step;
  }

  /// Returns the number of decimal places needed to represent [step] without
  /// trailing zeros — used to format the label.
  static int _decimals(double step) {
    if (step >= 1) return 0;
    final s = step.toString();
    final dotIndex = s.indexOf('.');
    if (dotIndex < 0) return 0;
    return s.length - dotIndex - 1;
  }
}
