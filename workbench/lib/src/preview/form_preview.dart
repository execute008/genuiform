import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import '../scenarios/lead_qualification_form.dart';
import 'debug_strip.dart';

/// Right-pane preview widget.
///
/// Renders the hardcoded [leadQualificationForm] as a [GenuiForm] and a
/// [DebugStrip] below it. The form's internal [FormController] is hoisted
/// out via the new `onControllerCreated` callback so the debug strip can
/// subscribe to live session updates without us re-implementing the form.
class FormPreview extends StatefulWidget {
  const FormPreview({
    required this.client,
    required this.model,
    super.key,
  });

  /// The LLM transport forwarded to the inner form.
  final LlmClient client;

  /// The Vertex AI model string.
  final String model;

  @override
  State<FormPreview> createState() => _FormPreviewState();
}

class _FormPreviewState extends State<FormPreview> {
  final ValueNotifier<FormController?> _controller =
      ValueNotifier<FormController?>(null);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: leadQualificationForm(
            client: widget.client,
            model: widget.model,
            onControllerCreated: (c) => _controller.value = c,
          ),
        ),
        ValueListenableBuilder<FormController?>(
          valueListenable: _controller,
          builder: (context, controller, _) {
            if (controller == null) {
              return const _DebugStripPlaceholder();
            }
            return DebugStrip(controller: controller);
          },
        ),
      ],
    );
  }
}

class _DebugStripPlaceholder extends StatelessWidget {
  const _DebugStripPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Text(
        'Debug strip — waiting for form to start…',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}
