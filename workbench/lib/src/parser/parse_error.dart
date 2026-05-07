/// A structured parse error produced by the DSL lexer, parser, or builder.
///
/// Carries [line] and [column] (both 1-based), a short [message], and an
/// optional [hint] with additional guidance.
class ParseError implements Exception {
  const ParseError({
    required this.line,
    required this.column,
    required this.message,
    this.hint,
  });

  /// 1-based line number where the error occurred.
  final int line;

  /// 1-based column number where the error occurred.
  final int column;

  /// Short, user-facing description of the error.
  final String message;

  /// Optional follow-up hint (e.g. "Did you mean X?", link to spec section).
  final String? hint;

  @override
  String toString() {
    final buf = StringBuffer('Line $line: $message');
    if (hint != null) {
      buf.write('\n  Hint: $hint');
    }
    return buf.toString();
  }

  /// Formats the error for display in the workbench editor footer or overlay.
  ///
  /// Returns a two-element list: [main-line, hint-line?].
  /// The hint element is empty string when there is no hint.
  String toFormatted() {
    final main = 'Line $line, col $column: $message';
    if (hint != null) {
      return '$main\n  Hint: $hint';
    }
    return main;
  }
}
