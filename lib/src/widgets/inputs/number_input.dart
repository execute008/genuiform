import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/quiz_step_spec.dart';
import '_validation_message.dart';

/// A numeric text input widget.
///
/// Reads the following keys from [spec.configuration]:
/// - `min` (`num?`): minimum value (used for display validation only).
/// - `max` (`num?`): maximum value (used for display validation only).
/// - `step` (`num?`): unused by the widget (informational for the LLM).
/// - `allowDecimal` (`bool`): when `true`, parses the input as `double`
///   (default `false`, parses as `int`).
///
/// [value] is a `num?`. [onChanged] emits a `num` — an `int` when
/// `allowDecimal` is `false`, otherwise a `double`.
///
/// Out-of-range values still trigger [onChanged]; the widget shows an inline
/// error to give the user immediate feedback. The authoritative validation
/// message for form-level errors is passed via [validationMessage].
class NumberInput extends StatefulWidget {
  const NumberInput({
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
  State<NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<NumberInput> {
  late final TextEditingController _controller;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.value as num?)?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = (widget.value as num?)?.toString() ?? '';
    if (_controller.text != newText) {
      _controller.text = newText;
      _controller.selection =
          TextSelection.collapsed(offset: newText.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChange(String text) {
    if (text.isEmpty) {
      setState(() => _rangeError = null);
      return;
    }

    final config = widget.spec.configuration ?? {};
    final allowDecimal = config['allowDecimal'] as bool? ?? false;
    final min = config['min'] as num?;
    final max = config['max'] as num?;

    final parsed = num.tryParse(text);
    if (parsed == null) return;

    final emitted = allowDecimal ? parsed.toDouble() : parsed.toInt();

    String? rangeError;
    if (min != null && parsed < min) {
      rangeError = 'Minimum value is $min';
    } else if (max != null && parsed > max) {
      rangeError = 'Maximum value is $max';
    }

    setState(() => _rangeError = rangeError);
    widget.onChanged(emitted);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.spec.configuration ?? {};
    final allowDecimal = config['allowDecimal'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          keyboardType: allowDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: [
            if (allowDecimal)
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))
            else
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
          ],
          onChanged: _handleChange,
          decoration: InputDecoration(
            errorText: _rangeError,
          ),
        ),
        ValidationMessage(widget.validationMessage),
      ],
    );
  }
}
