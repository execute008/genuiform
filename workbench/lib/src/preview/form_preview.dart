import 'package:flutter/material.dart';
import 'package:genuiform/genuiform.dart';

import 'debug_strip.dart';

/// Right-pane preview widget.
///
/// Renders a [GenuiForm] built from the four parsed primitives ([contract],
/// [constraints], [posture], [outcomes]) plus [client] and [model].
///
/// The form's internal [FormController] is hoisted out via
/// [GenuiForm.onControllerCreated] so the [DebugStrip] below can subscribe to
/// live session updates.
///
/// Re-keying this widget (via [ValueKey(_formKey)] in the shell) resets the
/// [FormController] cleanly.
class FormPreview extends StatefulWidget {
  const FormPreview({
    required this.contract,
    required this.constraints,
    required this.posture,
    required this.outcomes,
    required this.client,
    required this.model,
    super.key,
  });

  /// Parsed contract — what fields the LLM may collect.
  final Contract contract;

  /// Parsed constraints — rules the LLM must obey.
  final List<Constraint> constraints;

  /// Parsed posture — tone and pacing settings.
  final Posture posture;

  /// Parsed outcome tree root.
  final OutcomeNode outcomes;

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

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GenuiForm(
            contract: widget.contract,
            constraints: widget.constraints,
            posture: widget.posture,
            outcomes: widget.outcomes,
            client: widget.client,
            model: widget.model,
            onControllerCreated: (c) => _controller.value = c,
            onEscalation: (rule) {
              _showSnackbar('Escalated: ${rule.trigger}');
            },
            onError: (err) {
              _showSnackbar('Form error: $err');
            },
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
