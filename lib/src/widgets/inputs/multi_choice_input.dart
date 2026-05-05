import 'package:flutter/material.dart';

import '../../icons/icon_registry.dart';
import '../../models/quiz_choice.dart';
import '../../models/quiz_step_spec.dart';
import '_validation_message.dart';

/// A multi-select choice input widget.
///
/// Reads [spec.choices] to build a vertical list of toggle-able cards. Each
/// card shows:
/// - The icon resolved from [QuizChoice.iconName] via [IconRegistry.resolve].
/// - [QuizChoice.label] as the primary text.
/// - [QuizChoice.description] as optional secondary text.
///
/// [value] is a `List<dynamic>` of selected items. For normal choices items are
/// choice `id` Strings. For text-field choices items are `Map<String, dynamic>`:
/// ```json
/// {"choice": "<id>", "text": "<typed value>"}
/// ```
///
/// Tapping a card toggles its presence in the list. [onChanged] is called
/// after every toggle.
class MultiChoiceInput extends StatefulWidget {
  const MultiChoiceInput({
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
  State<MultiChoiceInput> createState() => _MultiChoiceInputState();
}

class _MultiChoiceInputState extends State<MultiChoiceInput> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<dynamic> _currentList() {
    final v = widget.value;
    if (v is List) return List<dynamic>.from(v);
    return <dynamic>[];
  }

  bool _isSelected(QuizChoice choice) {
    final list = _currentList();
    if (choice.isTextField) {
      return list.any((item) => item is Map && item['choice'] == choice.id);
    }
    return list.contains(choice.id);
  }

  void _toggle(QuizChoice choice) {
    final list = _currentList();
    if (choice.isTextField) {
      final alreadySelected =
          list.any((item) => item is Map && item['choice'] == choice.id);
      if (alreadySelected) {
        list.removeWhere((item) => item is Map && item['choice'] == choice.id);
      } else {
        final text = _controllers[choice.id]?.text ?? '';
        list.add({'choice': choice.id, 'text': text});
      }
    } else {
      if (list.contains(choice.id)) {
        list.remove(choice.id);
      } else {
        list.add(choice.id);
      }
    }
    widget.onChanged(list);
  }

  void _updateTextForChoice(QuizChoice choice, String text) {
    final list = _currentList();
    final index =
        list.indexWhere((item) => item is Map && item['choice'] == choice.id);
    if (index >= 0) {
      list[index] = {'choice': choice.id, 'text': text};
      widget.onChanged(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.spec.choices ?? const <QuizChoice>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...choices.map((choice) {
          final selected = _isSelected(choice);
          return _MultiChoiceCard(
            choice: choice,
            isSelected: selected,
            controller: choice.isTextField
                ? (_controllers[choice.id] ??= TextEditingController())
                : null,
            onTap: () => _toggle(choice),
            onTextChanged: choice.isTextField
                ? (text) => _updateTextForChoice(choice, text)
                : null,
          );
        }),
        ValidationMessage(widget.validationMessage),
      ],
    );
  }
}

class _MultiChoiceCard extends StatelessWidget {
  const _MultiChoiceCard({
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
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onTap(),
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
