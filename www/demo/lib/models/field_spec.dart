/// Input style, resolved by the contract system on the backend.
enum FieldInputStyle {
  outlined,
  filled,
  tonalCard,
  slider,
  choiceChips,
  switchControl,
}

class NumRange {
  final num min;
  final num max;
  const NumRange(this.min, this.max);
}

class FieldSpec {
  final String key;
  final String type;
  final bool required;
  final NumRange? range;
  final FieldInputStyle input;
  final String label;
  final String? hint;
  final List<String>? options;

  const FieldSpec({
    required this.key,
    required this.type,
    required this.required,
    required this.input,
    required this.label,
    this.hint,
    this.range,
    this.options,
  });
}
