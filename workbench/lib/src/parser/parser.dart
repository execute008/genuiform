import 'ast.dart';
import 'lexer.dart';
import 'parse_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Recursive-descent DSL parser
// ─────────────────────────────────────────────────────────────────────────────

/// Parses a list of [Token]s into a [FormNode].
///
/// Entry point: [parseForm].
///
/// Each parse method throws [ParseError] on any structural mismatch.
/// Errors carry the line/column of the offending token.
class Parser {
  Parser(this._tokens);

  final List<Token> _tokens;
  int _pos = 0;

  // ── Token helpers ──────────────────────────────────────────────────────────

  Token get _current => _pos < _tokens.length ? _tokens[_pos] : _tokens.last;

  Token _peek([int offset = 1]) {
    final i = _pos + offset;
    return i < _tokens.length ? _tokens[i] : _tokens.last;
  }

  /// Advance and return the token that was consumed.
  Token _advance() {
    final t = _current;
    if (_pos < _tokens.length - 1) _pos++;
    return t;
  }

  /// Consume the current token if it matches [kind].
  /// Throws [ParseError] with [errorMessage] otherwise.
  Token _expect(TokenKind kind, String errorMessage, {String? hint}) {
    final t = _current;
    if (t.kind != kind) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: errorMessage,
        hint: hint,
      );
    }
    return _advance();
  }

  /// Consume an identifier token whose [Token.value] is exactly [name].
  Token _expectIdent(String name, {String? hint}) {
    final t = _current;
    if (t.kind != TokenKind.ident || t.value != name) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Expected '$name' but found '${_tokenDescription(t)}'",
        hint: hint,
      );
    }
    return _advance();
  }

  bool _checkKind(TokenKind kind) => _current.kind == kind;

  /// Skip an optional trailing comma.
  void _skipOptionalComma() {
    if (_checkKind(TokenKind.comma)) _advance();
  }

  static String _tokenDescription(Token t) {
    if (t.kind == TokenKind.eof) return 'end of input';
    return t.value;
  }

  // ── Public entry point ─────────────────────────────────────────────────────

  /// Parses `final form = GenuiForm( ... );` and returns a [FormNode].
  FormNode parseForm() {
    // Detect unsupported keywords early.
    _checkForUnsupportedKeywords();

    final startLine = _current.line;
    final startCol = _current.column;

    _expectIdent('final');
    _expectIdent('form');
    _expect(TokenKind.equals, "Expected '=' after 'form'");
    _expectIdent('GenuiForm', hint: 'The DSL entry is: final form = GenuiForm(...)');
    _expect(TokenKind.lParen, "Expected '(' after 'GenuiForm'");

    ContractNode? contract;
    List<ConstraintNode>? constraints;
    PostureNode? posture;
    OutcomeAstNode? outcomes;

    // Named args in any order, each must appear exactly once.
    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      final argName = _expectNamedArgKey();
      switch (argName) {
        case 'contract':
          if (contract != null) {
            throw ParseError(
              line: _current.line,
              column: _current.column,
              message: "Duplicate named argument 'contract'",
            );
          }
          contract = _parseContract();
        case 'constraints':
          if (constraints != null) {
            throw ParseError(
              line: _current.line,
              column: _current.column,
              message: "Duplicate named argument 'constraints'",
            );
          }
          constraints = _parseConstraintList();
        case 'posture':
          if (posture != null) {
            throw ParseError(
              line: _current.line,
              column: _current.column,
              message: "Duplicate named argument 'posture'",
            );
          }
          posture = _parsePosture();
        case 'outcomes':
          if (outcomes != null) {
            throw ParseError(
              line: _current.line,
              column: _current.column,
              message: "Duplicate named argument 'outcomes'",
            );
          }
          outcomes = _parseOutcomeNode();
        default:
          throw ParseError(
            line: _current.line,
            column: _current.column,
            message: "Unknown argument '$argName' in GenuiForm",
            hint: 'Valid args: contract, constraints, posture, outcomes',
          );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close GenuiForm(...)");
    _skipOptionalComma();
    // Optional semicolon at end.
    if (_checkKind(TokenKind.semicolon)) _advance();

    if (contract == null) {
      throw ParseError(
        line: startLine,
        column: startCol,
        message: "GenuiForm is missing required argument 'contract'",
      );
    }
    if (constraints == null) {
      throw ParseError(
        line: startLine,
        column: startCol,
        message: "GenuiForm is missing required argument 'constraints'",
      );
    }
    if (posture == null) {
      throw ParseError(
        line: startLine,
        column: startCol,
        message: "GenuiForm is missing required argument 'posture'",
      );
    }
    if (outcomes == null) {
      throw ParseError(
        line: startLine,
        column: startCol,
        message: "GenuiForm is missing required argument 'outcomes'",
      );
    }

    return FormNode(
      contract: contract,
      constraints: constraints,
      posture: posture,
      outcomes: outcomes,
      line: startLine,
      column: startCol,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Contract
  // ─────────────────────────────────────────────────────────────────────────

  ContractNode _parseContract() {
    final startLine = _current.line;
    final startCol = _current.column;
    _expectIdent('Contract');
    _expect(TokenKind.lParen, "Expected '(' after 'Contract'");
    _expectIdent('fields', hint: 'Contract takes a single named arg: fields: {...}');
    _expect(TokenKind.colon, "Expected ':' after 'fields'");
    _expect(TokenKind.lBrace, "Expected '{' to begin fields map");

    final fields = <String, FieldSpecNode>{};
    while (!_checkKind(TokenKind.rBrace) && !_checkKind(TokenKind.eof)) {
      final keyToken = _expect(TokenKind.string, "Expected string key for field (e.g. 'name')");
      _expect(TokenKind.colon, "Expected ':' after field key '${keyToken.value}'");
      final spec = _parseFieldSpec();
      fields[keyToken.value] = spec;
      _skipOptionalComma();
    }

    _expect(TokenKind.rBrace, "Expected '}' to close fields map");
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close Contract(...)");

    return ContractNode(fields: fields, line: startLine, column: startCol);
  }

  FieldSpecNode _parseFieldSpec() {
    final startToken = _current;
    _expectIdent('FieldSpec');
    _expect(TokenKind.lParen, "Expected '(' after 'FieldSpec'");

    String? type;
    bool? required;
    String? description;
    List<dynamic>? enumValues;
    NumRangeNode? range;
    int? minLength;
    int? maxLength;

    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      final argName = _expectNamedArgKey();
      switch (argName) {
        case 'type':
          final typeToken = _current;
          if (typeToken.kind == TokenKind.ident) {
            _advance();
            // Validate supported types.
            const supported = {'String', 'int', 'double', 'bool', 'DateTime', 'List', 'Enum'};
            if (!supported.contains(typeToken.value)) {
              throw ParseError(
                line: typeToken.line,
                column: typeToken.column,
                message: "Unsupported FieldSpec type '${typeToken.value}'",
                hint: 'Supported types: ${supported.join(', ')}',
              );
            }
            type = typeToken.value;
          } else {
            throw ParseError(
              line: typeToken.line,
              column: typeToken.column,
              message: "Expected a type name (e.g. String, int, double) for FieldSpec.type",
            );
          }
        case 'required':
          final boolToken = _current;
          if (boolToken.kind != TokenKind.bool_) {
            throw ParseError(
              line: boolToken.line,
              column: boolToken.column,
              message: "Expected 'true' or 'false' for FieldSpec.required",
            );
          }
          _advance();
          required = boolToken.value == 'true';
        case 'description':
          final s = _expect(TokenKind.string, "Expected string literal for FieldSpec.description");
          description = s.value;
        case 'enumValues':
          enumValues = _parseListLiteral();
        case 'range':
          range = _parseNumRange();
        case 'minLength':
          minLength = _parseIntLiteral('minLength');
        case 'maxLength':
          maxLength = _parseIntLiteral('maxLength');
        default:
          throw ParseError(
            line: _current.line,
            column: _current.column,
            message: "Unknown FieldSpec argument '$argName'",
            hint: 'Valid args: type, required, description, enumValues, range, minLength, maxLength',
          );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close FieldSpec(...)");

    if (type == null) {
      throw ParseError(
        line: startToken.line,
        column: startToken.column,
        message: "FieldSpec is missing required argument 'type'",
      );
    }
    if (required == null) {
      throw ParseError(
        line: startToken.line,
        column: startToken.column,
        message: "FieldSpec is missing required argument 'required'",
      );
    }

    return FieldSpecNode(
      type: type,
      required: required,
      description: description,
      enumValues: enumValues,
      range: range,
      minLength: minLength,
      maxLength: maxLength,
      line: startToken.line,
      column: startToken.column,
    );
  }

  NumRangeNode _parseNumRange() {
    final startToken = _current;
    _expectIdent('NumRange');
    _expect(TokenKind.lParen, "Expected '(' after 'NumRange'");

    num? min;
    num? max;

    // NumRange supports positional or named args: NumRange(15, 240) or NumRange(min: 15, max: 240).
    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      // Check if this is a named arg (ident followed by colon).
      if (_checkKind(TokenKind.ident) && _peek().kind == TokenKind.colon) {
        final name = _advance().value;
        _advance(); // colon
        final n = _parseNumLiteral(name);
        if (name == 'min') {
          min = n;
        } else if (name == 'max') {
          max = n;
        } else {
          throw ParseError(
            line: _current.line,
            column: _current.column,
            message: "Unknown NumRange argument '$name'",
            hint: 'Valid args: min, max',
          );
        }
      } else {
        // Positional: first is min, second is max.
        final n = _parseNumLiteral('min or max');
        if (min == null) {
          min = n;
        } else {
          max = n;
        }
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close NumRange(...)");

    return NumRangeNode(
      min: min,
      max: max,
      line: startToken.line,
      column: startToken.column,
    );
  }

  num _parseNumLiteral(String context) {
    final t = _current;
    if (t.kind != TokenKind.number) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Expected number for '$context' but found '${_tokenDescription(t)}'",
      );
    }
    _advance();
    return t.value.contains('.') ? double.parse(t.value) : int.parse(t.value);
  }

  int _parseIntLiteral(String context) {
    final t = _current;
    if (t.kind != TokenKind.number) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Expected integer for '$context' but found '${_tokenDescription(t)}'",
      );
    }
    if (t.value.contains('.')) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Expected integer for '$context', got decimal '${t.value}'",
      );
    }
    _advance();
    return int.parse(t.value);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Constraints
  // ─────────────────────────────────────────────────────────────────────────

  List<ConstraintNode> _parseConstraintList() {
    _expect(TokenKind.lBrack, "Expected '[' to begin constraints list");
    final list = <ConstraintNode>[];

    while (!_checkKind(TokenKind.rBrack) && !_checkKind(TokenKind.eof)) {
      list.add(_parseConstraint());
      _skipOptionalComma();
    }

    _expect(TokenKind.rBrack, "Expected ']' to close constraints list");
    return list;
  }

  ConstraintNode _parseConstraint() {
    final t = _current;
    if (t.kind != TokenKind.ident) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Expected constraint constructor name, found '${_tokenDescription(t)}'",
      );
    }

    switch (t.value) {
      case 'NeverCollect':
        return _parseNeverCollect();
      case 'NeverSkip':
        return _parseNeverSkip();
      case 'MaxSteps':
        return _parseMaxSteps();
      case 'MinSteps':
        return _parseMinSteps();
      case 'WhitelistChoices':
        return _parseWhitelistChoices();
      case 'EscalateIf':
        return _parseEscalateIf();
      case 'StopIf':
        return _parseStopIf();
      case 'RequireConsent':
        return _parseRequireConsent();
      default:
        throw ParseError(
          line: t.line,
          column: t.column,
          message: "Unknown constraint '${t.value}'",
          hint: 'Valid constraints: NeverCollect, NeverSkip, MaxSteps, MinSteps, '
              'WhitelistChoices, EscalateIf, StopIf, RequireConsent',
        );
    }
  }

  NeverCollectNode _parseNeverCollect() {
    final start = _advance(); // 'NeverCollect'
    _expect(TokenKind.lParen, "Expected '(' after 'NeverCollect'");
    final arg = _expect(TokenKind.string, "Expected string argument for NeverCollect");
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close NeverCollect(...)");
    return NeverCollectNode(fieldOrTopic: arg.value, line: start.line, column: start.column);
  }

  NeverSkipNode _parseNeverSkip() {
    final start = _advance(); // 'NeverSkip'
    _expect(TokenKind.lParen, "Expected '(' after 'NeverSkip'");
    final ids = _parseStringListLiteral('NeverSkip');
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close NeverSkip(...)");
    return NeverSkipNode(fieldIds: ids, line: start.line, column: start.column);
  }

  MaxStepsNode _parseMaxSteps() {
    final start = _advance(); // 'MaxSteps'
    _expect(TokenKind.lParen, "Expected '(' after 'MaxSteps'");
    // MaxSteps takes a positional integer argument.
    final t = _current;
    if (t.kind == TokenKind.string) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Type error: MaxSteps expects a number, not a string '${t.value}'",
        hint: 'Example: MaxSteps(8)',
      );
    }
    final value = _parseIntLiteral('MaxSteps');
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close MaxSteps(...)");
    return MaxStepsNode(value: value, line: start.line, column: start.column);
  }

  MinStepsNode _parseMinSteps() {
    final start = _advance(); // 'MinSteps'
    _expect(TokenKind.lParen, "Expected '(' after 'MinSteps'");
    final t = _current;
    if (t.kind == TokenKind.string) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Type error: MinSteps expects a number, not a string '${t.value}'",
        hint: 'Example: MinSteps(3)',
      );
    }
    final value = _parseIntLiteral('MinSteps');
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close MinSteps(...)");
    return MinStepsNode(value: value, line: start.line, column: start.column);
  }

  WhitelistChoicesNode _parseWhitelistChoices() {
    final start = _advance(); // 'WhitelistChoices'
    _expect(TokenKind.lParen, "Expected '(' after 'WhitelistChoices'");
    final fieldIdToken = _expect(
      TokenKind.string,
      "Expected string field ID as first argument to WhitelistChoices",
    );
    _expect(TokenKind.comma, "Expected ',' after field ID in WhitelistChoices");
    final allowed = _parseListLiteral();
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close WhitelistChoices(...)");
    return WhitelistChoicesNode(
      fieldId: fieldIdToken.value,
      allowed: allowed,
      line: start.line,
      column: start.column,
    );
  }

  EscalateIfNode _parseEscalateIf() {
    final start = _advance(); // 'EscalateIf'
    _expect(TokenKind.lParen, "Expected '(' after 'EscalateIf'");
    final trigger = _expect(TokenKind.string, "Expected string trigger for EscalateIf");
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close EscalateIf(...)");
    return EscalateIfNode(trigger: trigger.value, line: start.line, column: start.column);
  }

  StopIfNode _parseStopIf() {
    final start = _advance(); // 'StopIf'
    _expect(TokenKind.lParen, "Expected '(' after 'StopIf'");
    final trigger = _expect(TokenKind.string, "Expected string trigger for StopIf");
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close StopIf(...)");
    return StopIfNode(trigger: trigger.value, line: start.line, column: start.column);
  }

  RequireConsentNode _parseRequireConsent() {
    final start = _advance(); // 'RequireConsent'
    _expect(TokenKind.lParen, "Expected '(' after 'RequireConsent'");
    final topic = _expect(TokenKind.string, "Expected string topic for RequireConsent");
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close RequireConsent(...)");
    return RequireConsentNode(topic: topic.value, line: start.line, column: start.column);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Posture
  // ─────────────────────────────────────────────────────────────────────────

  PostureNode _parsePosture() {
    final startToken = _current;
    _expectIdent('Posture');

    // `Posture.somePreset()` or `Posture(...)`
    if (_checkKind(TokenKind.dot)) {
      _advance(); // '.'
      final presetToken = _current;
      if (presetToken.kind != TokenKind.ident) {
        throw ParseError(
          line: presetToken.line,
          column: presetToken.column,
          message: "Expected preset name after 'Posture.'",
          hint: 'Valid presets: salesDiscovery, supportiveOnboarding, clinicalIntake',
        );
      }
      const validPresets = {'salesDiscovery', 'supportiveOnboarding', 'clinicalIntake'};
      if (!validPresets.contains(presetToken.value)) {
        throw ParseError(
          line: presetToken.line,
          column: presetToken.column,
          message: "Unknown Posture preset '${presetToken.value}'",
          hint: 'Valid presets: ${validPresets.join(', ')}',
        );
      }
      _advance(); // preset name
      _expect(TokenKind.lParen, "Expected '(' after preset name");
      _expect(TokenKind.rParen, "Expected ')' to close preset call");
      return PosturePresetNode(
        preset: presetToken.value,
        line: startToken.line,
        column: startToken.column,
      );
    }

    // Literal `Posture(persistence: ..., ...)`
    _expect(TokenKind.lParen, "Expected '(' after 'Posture'");

    int? persistence;
    int? exploration;
    int? pacing;
    int? skipTolerance;
    String? voice;

    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      final argName = _expectNamedArgKey();
      switch (argName) {
        case 'persistence':
          persistence = _parseIntLiteral('persistence');
        case 'exploration':
          exploration = _parseIntLiteral('exploration');
        case 'pacing':
          pacing = _parseIntLiteral('pacing');
        case 'skipTolerance':
          skipTolerance = _parseIntLiteral('skipTolerance');
        case 'voice':
          final s = _expect(TokenKind.string, "Expected string for Posture.voice");
          voice = s.value;
        default:
          throw ParseError(
            line: _current.line,
            column: _current.column,
            message: "Unknown Posture argument '$argName'",
            hint: 'Valid args: persistence, exploration, pacing, skipTolerance, voice',
          );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close Posture(...)");

    for (final kv in [
      ['persistence', persistence],
      ['exploration', exploration],
      ['pacing', pacing],
      ['skipTolerance', skipTolerance],
      ['voice', voice],
    ]) {
      if (kv[1] == null) {
        throw ParseError(
          line: startToken.line,
          column: startToken.column,
          message: "Posture is missing required argument '${kv[0]}'",
        );
      }
    }

    return PostureLiteralNode(
      persistence: persistence!,
      exploration: exploration!,
      pacing: pacing!,
      skipTolerance: skipTolerance!,
      voice: voice!,
      line: startToken.line,
      column: startToken.column,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Outcome nodes
  // ─────────────────────────────────────────────────────────────────────────

  OutcomeAstNode _parseOutcomeNode() {
    final t = _current;
    if (t.kind != TokenKind.ident) {
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Expected outcome node constructor (Layer, Branch, or Outcome), found '${_tokenDescription(t)}'",
      );
    }
    switch (t.value) {
      case 'Layer':
        return _parseLayer();
      case 'Branch':
        return _parseBranch();
      case 'Outcome':
        return _parseOutcomeTerminal();
      default:
        throw ParseError(
          line: t.line,
          column: t.column,
          message: "Unknown outcome node '${t.value}'",
          hint: 'Valid outcome nodes: Layer, Branch, Outcome',
        );
    }
  }

  LayerAstNode _parseLayer() {
    final start = _advance(); // 'Layer'
    _expect(TokenKind.lParen, "Expected '(' after 'Layer'");

    // First positional arg: string id.
    final idToken = _current;
    if (idToken.kind != TokenKind.string) {
      throw ParseError(
        line: idToken.line,
        column: idToken.column,
        message: "Expected string literal as first argument to Layer (the id)",
        hint: "Example: Layer('account_only', contractDelta: ..., next: ...)",
      );
    }
    final id = _advance().value;
    _skipOptionalComma();

    ContractNode? contractDelta;
    OutcomeAstNode? next;
    HandoffStubNode? handoff;

    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      final argName = _expectNamedArgKey();
      switch (argName) {
        case 'contractDelta':
          contractDelta = _parseContract();
        case 'next':
          next = _parseOutcomeNode();
        case 'handoff':
          handoff = _parseHandoffStub();
        default:
          throw ParseError(
            line: _current.line,
            column: _current.column,
            message: "Unknown Layer argument '$argName'",
            hint: 'Valid args: contractDelta, next, handoff',
          );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close Layer(...)");

    if (contractDelta == null) {
      throw ParseError(
        line: start.line,
        column: start.column,
        message: "Layer '$id' is missing required argument 'contractDelta'",
      );
    }

    return LayerAstNode(
      id: id,
      contractDelta: contractDelta,
      next: next,
      handoff: handoff,
      line: start.line,
      column: start.column,
    );
  }

  BranchAstNode _parseBranch() {
    final start = _advance(); // 'Branch'
    _expect(TokenKind.lParen, "Expected '(' after 'Branch'");

    // First positional arg: string id.
    final idToken = _current;
    if (idToken.kind != TokenKind.string) {
      throw ParseError(
        line: idToken.line,
        column: idToken.column,
        message: "Expected string literal as first argument to Branch (the id)",
        hint: "Example: Branch('lead_split', options: [...])",
      );
    }
    final id = _advance().value;
    _skipOptionalComma();

    List<BranchOptionAstNode>? options;

    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      final argName = _expectNamedArgKey();
      if (argName == 'options') {
        options = _parseBranchOptionList();
      } else {
        throw ParseError(
          line: _current.line,
          column: _current.column,
          message: "Unknown Branch argument '$argName'",
          hint: "Branch takes: options: [...]",
        );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close Branch(...)");

    if (options == null || options.isEmpty) {
      throw ParseError(
        line: start.line,
        column: start.column,
        message: "Branch '$id' is missing required argument 'options' (or options list is empty)",
        hint: "Example: Branch('id', options: [BranchOption(...)])",
      );
    }

    return BranchAstNode(id: id, options: options, line: start.line, column: start.column);
  }

  List<BranchOptionAstNode> _parseBranchOptionList() {
    _expect(TokenKind.lBrack, "Expected '[' to begin Branch options list");
    final list = <BranchOptionAstNode>[];

    while (!_checkKind(TokenKind.rBrack) && !_checkKind(TokenKind.eof)) {
      list.add(_parseBranchOption());
      _skipOptionalComma();
    }

    _expect(TokenKind.rBrack, "Expected ']' to close Branch options list");
    return list;
  }

  BranchOptionAstNode _parseBranchOption() {
    final start = _current;
    _expectIdent('BranchOption');
    _expect(TokenKind.lParen, "Expected '(' after 'BranchOption'");

    final idToken = _current;
    if (idToken.kind != TokenKind.string) {
      throw ParseError(
        line: idToken.line,
        column: idToken.column,
        message: "Expected string literal as first argument to BranchOption (the id)",
      );
    }
    final id = _advance().value;
    _skipOptionalComma();

    String? criterion;
    ContractNode? contractDelta;
    OutcomeAstNode? child;

    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      final argName = _expectNamedArgKey();
      switch (argName) {
        case 'criterion':
          final s = _expect(TokenKind.string, "Expected string for BranchOption.criterion");
          criterion = s.value;
        case 'contractDelta':
          contractDelta = _parseContract();
        case 'child':
          child = _parseOutcomeNode();
        default:
          throw ParseError(
            line: _current.line,
            column: _current.column,
            message: "Unknown BranchOption argument '$argName'",
            hint: 'Valid args: criterion, contractDelta, child',
          );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close BranchOption(...)");

    if (criterion == null) {
      throw ParseError(
        line: start.line,
        column: start.column,
        message: "BranchOption '$id' is missing required argument 'criterion'",
      );
    }
    if (child == null) {
      throw ParseError(
        line: start.line,
        column: start.column,
        message: "BranchOption '$id' is missing required argument 'child'",
      );
    }

    return BranchOptionAstNode(
      id: id,
      criterion: criterion,
      contractDelta: contractDelta,
      child: child,
      line: start.line,
      column: start.column,
    );
  }

  OutcomeTerminalNode _parseOutcomeTerminal() {
    final start = _advance(); // 'Outcome'
    _expect(TokenKind.lParen, "Expected '(' after 'Outcome'");

    final idToken = _current;
    if (idToken.kind != TokenKind.string) {
      throw ParseError(
        line: idToken.line,
        column: idToken.column,
        message: "Expected string literal as first argument to Outcome (the id)",
      );
    }
    final id = _advance().value;
    _skipOptionalComma();

    ContractNode? contractDelta;
    HandoffStubNode? handoff;

    while (!_checkKind(TokenKind.rParen) && !_checkKind(TokenKind.eof)) {
      final argName = _expectNamedArgKey();
      switch (argName) {
        case 'contractDelta':
          contractDelta = _parseContract();
        case 'handoff':
          handoff = _parseHandoffStub();
        default:
          throw ParseError(
            line: _current.line,
            column: _current.column,
            message: "Unknown Outcome argument '$argName'",
            hint: 'Valid args: contractDelta, handoff',
          );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rParen, "Expected ')' to close Outcome(...)");

    if (contractDelta == null) {
      throw ParseError(
        line: start.line,
        column: start.column,
        message: "Outcome '$id' is missing required argument 'contractDelta'",
      );
    }

    return OutcomeTerminalNode(
      id: id,
      contractDelta: contractDelta,
      handoff: handoff,
      line: start.line,
      column: start.column,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Handoff stub
  // ─────────────────────────────────────────────────────────────────────────

  HandoffStubNode _parseHandoffStub() {
    final start = _current;
    _expectIdent('Handoff');
    _expect(TokenKind.lParen, "Expected '(' after 'Handoff'");
    _expectIdent('onReached', hint: 'Handoff syntax: Handoff(onReached: registryKey)');
    _expect(TokenKind.colon, "Expected ':' after 'onReached'");

    final keyToken = _current;
    if (keyToken.kind != TokenKind.ident) {
      throw ParseError(
        line: keyToken.line,
        column: keyToken.column,
        message: "Expected registry key identifier after 'onReached:'",
        hint: 'Example: Handoff(onReached: bookCalendly)',
      );
    }
    _advance();
    _skipOptionalComma();
    _expect(TokenKind.rParen, "Expected ')' to close Handoff(...)");

    return HandoffStubNode(
      registryKey: keyToken.value,
      line: start.line,
      column: start.column,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // List / value helpers
  // ─────────────────────────────────────────────────────────────────────────

  List<dynamic> _parseListLiteral() {
    _expect(TokenKind.lBrack, "Expected '[' to begin list");
    final items = <dynamic>[];

    while (!_checkKind(TokenKind.rBrack) && !_checkKind(TokenKind.eof)) {
      final t = _current;
      if (t.kind == TokenKind.string) {
        items.add(_advance().value);
      } else if (t.kind == TokenKind.number) {
        final raw = _advance().value;
        items.add(raw.contains('.') ? double.parse(raw) : int.parse(raw));
      } else if (t.kind == TokenKind.bool_) {
        items.add(_advance().value == 'true');
      } else {
        throw ParseError(
          line: t.line,
          column: t.column,
          message: "Unexpected value in list: '${_tokenDescription(t)}' — expected string, number, or bool",
        );
      }
      _skipOptionalComma();
    }

    _expect(TokenKind.rBrack, "Expected ']' to close list");
    return items;
  }

  List<String> _parseStringListLiteral(String context) {
    _expect(TokenKind.lBrack, "Expected '[' to begin $context list");
    final items = <String>[];

    while (!_checkKind(TokenKind.rBrack) && !_checkKind(TokenKind.eof)) {
      final t = _expect(TokenKind.string, "Expected string in $context list");
      items.add(t.value);
      _skipOptionalComma();
    }

    _expect(TokenKind.rBrack, "Expected ']' to close $context list");
    return items;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Named arg key helper
  // ─────────────────────────────────────────────────────────────────────────

  /// Reads `identName :` and returns `identName`.
  String _expectNamedArgKey() {
    final t = _current;
    if (t.kind != TokenKind.ident) {
      _checkForUnsupportedToken(t);
      throw ParseError(
        line: t.line,
        column: t.column,
        message: "Expected named argument (identifier followed by ':'), found '${_tokenDescription(t)}'",
      );
    }
    _advance();
    _expect(TokenKind.colon, "Expected ':' after argument name '${t.value}'");
    return t.value;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Unsupported keyword detection
  // ─────────────────────────────────────────────────────────────────────────

  void _checkForUnsupportedKeywords() {
    // Pre-scan all tokens for language keywords not in the DSL.
    for (final t in _tokens) {
      if (t.kind == TokenKind.ident) {
        switch (t.value) {
          case 'if':
          case 'else':
          case 'for':
          case 'while':
          case 'do':
          case 'switch':
          case 'case':
          case 'return':
          case 'import':
          case 'class':
          case 'void':
          case 'var':
          case 'new':
          case 'null':
            throw ParseError(
              line: t.line,
              column: t.column,
              message: "Unexpected token '${t.value}' — the workbench DSL doesn't support this",
              hint: _unsupportedKeywordHint(t.value),
            );
        }
      }
    }
  }

  void _checkForUnsupportedToken(Token t) {
    if (t.kind == TokenKind.ident) {
      switch (t.value) {
        case 'if':
        case 'else':
        case 'for':
        case 'while':
        case 'switch':
          throw ParseError(
            line: t.line,
            column: t.column,
            message: "Unexpected token '${t.value}' — the workbench DSL doesn't support conditionals or loops",
            hint: 'Use scenario presets instead of conditionals',
          );
      }
    }
  }

  static String _unsupportedKeywordHint(String kw) {
    switch (kw) {
      case 'if':
      case 'else':
        return 'The workbench DSL doesn\'t support conditionals — use scenario presets instead';
      case 'for':
      case 'while':
      case 'do':
        return 'The workbench DSL doesn\'t support loops — use list literals instead';
      case 'import':
        return 'The workbench DSL doesn\'t support imports — all types are built-in';
      case 'class':
        return 'The workbench DSL doesn\'t support class definitions';
      case 'return':
        return 'The workbench DSL doesn\'t support return statements';
      case 'null':
        return 'Use an empty Contract(fields: {}) instead of null for contractDelta';
      case 'new':
        return 'The DSL doesn\'t use new — just call the constructor directly';
      default:
        return 'The workbench DSL is a restricted subset of Dart — see the DSL badge for details';
    }
  }
}
