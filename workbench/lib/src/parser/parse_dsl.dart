import 'package:genuiform/genuiform.dart';

import '../registry/handoff_registry.dart';
import 'builder.dart';
import 'lexer.dart';
import 'parse_error.dart';
import 'parser.dart';

/// The result of parsing and building a DSL [source] string.
///
/// Exposes the four genuiform primitives directly so the workbench can
/// wrap them in a [GenuiForm] at render time with the real [LlmClient].
class ParseResult {
  const ParseResult({
    this.contract,
    this.constraints,
    this.posture,
    this.outcomes,
    this.handoffMap,
    required this.errors,
  });

  /// The collected contract, or null on fatal parse failure.
  final Contract? contract;

  /// The collected constraints list, or null on fatal parse failure.
  final List<Constraint>? constraints;

  /// The posture, or null on fatal parse failure.
  final Posture? posture;

  /// The outcome tree root, or null on fatal parse failure.
  final OutcomeNode? outcomes;

  /// Side-table mapping each [Outcome.id] to its [SimulatedHandoff].
  /// Used by [FormPreview] to show a toast when [GenuiForm.onComplete] fires.
  /// Null on fatal parse failure.
  final Map<String, SimulatedHandoff>? handoffMap;

  /// All errors encountered during lexing, parsing, or building.
  final List<ParseError> errors;

  /// True iff the four primitives are all present (the form can render).
  bool get hasForm =>
      contract != null && constraints != null && posture != null && outcomes != null;

  /// True when there are any errors at all (fatal or soft).
  bool get hasErrors => errors.isNotEmpty;

  /// True when no errors were encountered and the form is fully resolved.
  bool get isClean => errors.isEmpty && hasForm;
}

/// Parses and builds [source] into a [ParseResult].
///
/// This is the single entry point for the workbench. It is safe to call on
/// every keystroke — all [ParseError]s are caught and returned in the result;
/// the workbench never crashes from DSL errors.
///
/// ### Error handling
///
/// - Lexer and parser [ParseError]s are caught and placed in [ParseResult.errors].
/// - Builder [ParseError]s (soft errors, e.g. unknown handoff key) are
///   appended to the error list; a partial form is still returned.
/// - Any unexpected [Exception] is wrapped as a parser-internal-error
///   [ParseError] at line 1, col 1.
ParseResult parseDsl(String source) {
  try {
    final tokens = Lexer(source).tokenize();
    final ast = Parser(tokens).parseForm();
    final buildResult = DslBuilder().build(ast);
    return ParseResult(
      contract: buildResult.contract,
      constraints: buildResult.constraints,
      posture: buildResult.posture,
      outcomes: buildResult.outcomes,
      handoffMap: buildResult.handoffMap,
      errors: buildResult.errors,
    );
  } on ParseError catch (e) {
    return ParseResult(errors: [e]);
  } catch (e) {
    return ParseResult(
      errors: [
        ParseError(
          line: 1,
          column: 1,
          message: 'Parser internal error: $e',
          hint: 'This is a workbench bug — please report it',
        ),
      ],
    );
  }
}
