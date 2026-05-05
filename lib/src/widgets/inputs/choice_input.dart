import 'package:flutter/material.dart';

import '../../icons/icon_registry.dart';
import '../../models/quiz_choice.dart';
import '../../models/quiz_step_spec.dart';
import '_validation_message.dart';

/// A single-select choice input widget.
///
/// Reads [spec.choices] to build a vertical list of selectable cards. Each
/// card shows:
/// - The icon resolved from [QuizChoice.iconName] via [IconRegistry.resolve].
/// - [QuizChoice.label] as the primary text.
/// - [QuizChoice.description] as optional secondary text.
///
/// When [QuizChoice.isTextField] is `true`, selecting that card reveals a
/// [TextFormField] beneath it. In that case [onChanged] is called with a
/// `Map<String, dynamic>` of the shape:
/// ```json
/// {"choice": "<id>", "text": "<typed value>"}
/// ```
/// For all other choices [onChanged] is called with the choice `id` String.
///
/// [value] is either the selected choice `id` (String) or a `Map<String, dynamic>`
/// when the selected choice is a text-field choice.
class ChoiceInput extends StatefulWidget {
  const ChoiceInput({
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
  State<ChoiceInput> createState() => _ChoiceInputState();
}

class _ChoiceInputState extends State<ChoiceInput> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _selectedId() {
    final v = widget.value;
    if (v is String) return v;
    if (v is Map) return v['choice'] as String?;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.spec.choices ?? const <QuizChoice>[];
    final selectedId = _selectedId();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...choices.map((choice) => _ChoiceCard(
              choice: choice,
              isSelected: selectedId == choice.id,
              controller: choice.isTextField
                  ? (_controllers[choice.id] ??= TextEditingController())
                  : null,
              onTap: () {
                if (choice.isTextField) {
                  final text = _controllers[choice.id]?.text ?? '';
                  widget.onChanged({'choice': choice.id, 'text': text});
                } else {
                  widget.onChanged(choice.id);
                }
              },
              onTextChanged: choice.isTextField
                  ? (text) => widget.onChanged({'choice': choice.id, 'text': text})
                  : null,
            )),
        ValidationMessage(widget.validationMessage),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.isSelected,
    required this.onTap,
    this.controller,
    this.onTextChanged,
  });

  final QuizChoice choice;
  final bool isSelected;
  final VoidCallback onTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onTextChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconData = IconRegistry.resolve(choice.iconName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Card(
            color: isSelected ? colorScheme.primaryContainer : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (iconData != null) ...[
                      Icon(
                        iconData,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            choice.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                          if (choice.description != null)
                            Text(
                              choice.description!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isSelected && choice.isTextField && controller != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Please specify…',
                ),
                onChanged: onTextChanged,
              ),
            ),
        ],
      ),
    );
  }
}
