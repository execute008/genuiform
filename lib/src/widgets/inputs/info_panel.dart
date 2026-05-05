import 'package:flutter/material.dart';

import '../../models/quiz_step_spec.dart';
import '_validation_message.dart';

/// An informational display panel — used for [QuizInputType.noneJustInformation]
/// steps.
///
/// Reads [spec.configuration\['information'\]] as the body text, falling back
/// to [spec.description] if the key is absent or null.
///
/// Renders a [Card] with:
/// - [spec.title] as a header (if non-null).
/// - The information text as the body.
/// - A "Continue" [FilledButton] that calls `onChanged(true)`, signalling
///   the user has acknowledged the information and is ready to proceed.
class InfoPanel extends StatelessWidget {
  const InfoPanel({
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
    final body =
        (config['information'] as String?) ?? spec.description ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spec.title.isNotEmpty) ...[
                  Text(
                    spec.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => onChanged(true),
          child: const Text('Continue'),
        ),
        ValidationMessage(validationMessage),
      ],
    );
  }
}
