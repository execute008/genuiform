import 'package:flutter/material.dart';

import '../../models/quiz_step_spec.dart';
import '_validation_message.dart';

/// A date picker input widget.
///
/// Reads the following keys from [spec.configuration]:
/// - `firstDate` (`String?`): ISO 8601 date string for the earliest selectable
///   date (default: 100 years before today).
/// - `lastDate` (`String?`): ISO 8601 date string for the latest selectable
///   date (default: today).
///
/// [value] is a `DateTime?`. Renders a tappable button that opens the Material
/// date picker dialog. [onChanged] is called with the selected [DateTime] when
/// the user confirms their pick.
class DateInput extends StatelessWidget {
  const DateInput({
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

  DateTime? get _dateValue {
    final v = value;
    if (v is DateTime) return v;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final config = spec.configuration ?? {};
    final now = DateTime.now();
    final firstDate = _parseDate(config['firstDate'] as String?) ??
        DateTime(now.year - 100, now.month, now.day);
    final lastDate =
        _parseDate(config['lastDate'] as String?) ?? now;

    final pickedDate = _dateValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(
            pickedDate != null ? _formatDate(pickedDate) : 'Pick a date',
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: pickedDate ?? now,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
        ),
        ValidationMessage(validationMessage),
      ],
    );
  }

  static DateTime? _parseDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso);
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
