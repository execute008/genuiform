import 'package:flutter/material.dart';

/// A small helper widget that renders a validation error message in red.
///
/// Shown beneath the input when [message] is non-null. When [message] is null
/// the widget renders nothing (`SizedBox.shrink`).
class ValidationMessage extends StatelessWidget {
  const ValidationMessage(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message!,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
    );
  }
}
