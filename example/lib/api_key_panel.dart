import 'package:flutter/material.dart';

/// A small panel that lets the user paste a sensitive string (e.g. a Gemini
/// API key or GCP project ID) at runtime without hard-coding it.
///
/// Priority order for the stored value:
/// 1. `--dart-define=GEMINI_API_KEY=xxx` (compile-time; caller passes it in
///    via [ValueNotifier] already initialised to `String.fromEnvironment(...)`).
/// 2. The value the user types and taps "Save".
/// 3. Empty string — the panel shows a "paste your key" prompt.
///
/// The widget never writes to permanent storage — the key lives only in this
/// app instance. A small subtitle reminds the user: "Your key stays in this
/// app instance. Never committed."
class ApiKeyPanel extends StatefulWidget {
  const ApiKeyPanel({
    required this.notifier,
    required this.label,
    super.key,
  });

  /// The [ValueNotifier] that holds the current value.
  ///
  /// Initialise it to `String.fromEnvironment(...)` so that compile-time
  /// defines are pre-filled. When the user taps "Save", the panel sets
  /// `notifier.value` to the trimmed text-field content. The parent should
  /// listen and rebuild.
  final ValueNotifier<String> notifier;

  /// Short label shown above the text field (e.g. "Gemini API key / OAuth token").
  final String label;

  @override
  State<ApiKeyPanel> createState() => _ApiKeyPanelState();
}

class _ApiKeyPanelState extends State<ApiKeyPanel> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.notifier.value);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    final trimmed = _textController.text.trim();
    widget.notifier.value = trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Paste your ${widget.label}',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your key stays in this app instance. Never committed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience getter that exposes the [ApiKeyPanel.label] so tests can query
/// the widget without digging into the tree. Accessed via the widget's public
/// field.
extension ApiKeyPanelLabel on ApiKeyPanel {
  String get labelText => label;
}
