import 'package:flutter/material.dart';

import '../../models/quiz_step_spec.dart';
import '_validation_message.dart';

/// A free-text input widget.
///
/// Reads the following keys from [spec.configuration]:
/// - `multiline` (`bool`): when `true`, the field expands vertically and
///   wraps (default `false`).
///
/// [value] is a `String?`. The field is initialised with [value] when the
/// widget is first built; subsequent external changes to [value] are reflected
/// via the [TextEditingController].
///
/// [onChanged] fires on every keystroke — debouncing is the [FormController]'s
/// responsibility.
class TextInput extends StatefulWidget {
  const TextInput({
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
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: (widget.value as String?) ?? '');
  }

  @override
  void didUpdateWidget(TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = (widget.value as String?) ?? '';
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

  @override
  Widget build(BuildContext context) {
    final config = widget.spec.configuration ?? {};
    final multiline = config['multiline'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _controller,
          maxLines: multiline ? null : 1,
          minLines: multiline ? 3 : 1,
          keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
          onChanged: widget.onChanged,
        ),
        ValidationMessage(widget.validationMessage),
      ],
    );
  }
}
