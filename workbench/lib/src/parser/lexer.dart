import 'dart:convert';

import 'parse_error.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Token kinds
// ─────────────────────────────────────────────────────────────────────────────

enum TokenKind {
  ident,
  string,
  number,
  bool_,
  lBrace,
  rBrace,
  lBrack,
  rBrack,
  lParen,
  rParen,
  comma,
  colon,
  dot,
  equals,
  semicolon,
  eof,
}

// ─────────────────────────────────────────────────────────────────────────────
// Token
// ─────────────────────────────────────────────────────────────────────────────

/// A single token produced by the [Lexer].
class Token {
  const Token({
    required this.kind,
    required this.value,
    required this.line,
    required this.column,
  });

  final TokenKind kind;

  /// The raw source text for the token (string content is already unescaped).
  final String value;

  /// 1-based line number.
  final int line;

  /// 1-based column number of the first character.
  final int column;

  @override
  String toString() => 'Token($kind, ${jsonEncode(value)}, $line:$column)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Lexer
// ─────────────────────────────────────────────────────────────────────────────

/// Tokenizes a DSL source string into a flat list of [Token]s.
///
/// ### Numbers
///
/// Numbers are always positive — a leading `-` is not consumed by the lexer;
/// the parser handles negative values where they appear (none of the DSL
/// scenarios require them, since NumRange min/max are always positive).
///
/// ### Booleans
///
/// `true` and `false` are emitted as [TokenKind.bool_] tokens (not [TokenKind.ident]).
///
/// ### Comments
///
/// `//` single-line and `/* ... */` block comments are stripped silently.
/// Unterminated block comments produce a [ParseError].
///
/// ### Strings
///
/// Both `'...'` and `"..."` delimiters are supported. Standard escapes
/// `\n \t \\ \' \"` are interpreted. String interpolation `${...}` is
/// rejected with a [ParseError].
class Lexer {
  Lexer(this._source);

  final String _source;
  int _pos = 0;
  int _line = 1;
  int _col = 1;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Tokenizes the entire source and returns the token list.
  ///
  /// Always ends with a single [TokenKind.eof] token.
  List<Token> tokenize() {
    final tokens = <Token>[];
    while (true) {
      _skipWhitespaceAndComments();
      if (_pos >= _source.length) {
        tokens.add(Token(kind: TokenKind.eof, value: '', line: _line, column: _col));
        break;
      }
      final token = _nextToken();
      tokens.add(token);
    }
    return tokens;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  String get _current => _pos < _source.length ? _source[_pos] : '';

  String _peek([int offset = 1]) {
    final i = _pos + offset;
    return i < _source.length ? _source[i] : '';
  }

  void _advance() {
    if (_pos < _source.length) {
      if (_source[_pos] == '\n') {
        _line++;
        _col = 1;
      } else {
        _col++;
      }
      _pos++;
    }
  }

  void _skipWhitespaceAndComments() {
    while (_pos < _source.length) {
      final ch = _current;
      if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
        _advance();
      } else if (ch == '/' && _peek() == '/') {
        // Line comment — skip until end of line.
        while (_pos < _source.length && _current != '\n') {
          _advance();
        }
      } else if (ch == '/' && _peek() == '*') {
        // Block comment.
        final startLine = _line;
        final startCol = _col;
        _advance(); // '/'
        _advance(); // '*'
        bool closed = false;
        while (_pos < _source.length) {
          if (_current == '*' && _peek() == '/') {
            _advance(); // '*'
            _advance(); // '/'
            closed = true;
            break;
          }
          _advance();
        }
        if (!closed) {
          throw ParseError(
            line: startLine,
            column: startCol,
            message: 'Unterminated block comment',
            hint: 'Close the comment with */',
          );
        }
      } else {
        break;
      }
    }
  }

  Token _nextToken() {
    final startLine = _line;
    final startCol = _col;
    final ch = _current;

    // ── Punctuation ──────────────────────────────────────────────────────────
    switch (ch) {
      case '{':
        _advance();
        return Token(kind: TokenKind.lBrace, value: '{', line: startLine, column: startCol);
      case '}':
        _advance();
        return Token(kind: TokenKind.rBrace, value: '}', line: startLine, column: startCol);
      case '[':
        _advance();
        return Token(kind: TokenKind.lBrack, value: '[', line: startLine, column: startCol);
      case ']':
        _advance();
        return Token(kind: TokenKind.rBrack, value: ']', line: startLine, column: startCol);
      case '(':
        _advance();
        return Token(kind: TokenKind.lParen, value: '(', line: startLine, column: startCol);
      case ')':
        _advance();
        return Token(kind: TokenKind.rParen, value: ')', line: startLine, column: startCol);
      case ',':
        _advance();
        return Token(kind: TokenKind.comma, value: ',', line: startLine, column: startCol);
      case ':':
        _advance();
        return Token(kind: TokenKind.colon, value: ':', line: startLine, column: startCol);
      case '.':
        _advance();
        return Token(kind: TokenKind.dot, value: '.', line: startLine, column: startCol);
      case '=':
        _advance();
        return Token(kind: TokenKind.equals, value: '=', line: startLine, column: startCol);
      case ';':
        _advance();
        return Token(kind: TokenKind.semicolon, value: ';', line: startLine, column: startCol);
    }

    // ── String literals ──────────────────────────────────────────────────────
    if (ch == '"' || ch == "'") {
      return _lexString(startLine, startCol);
    }

    // ── Number literals ──────────────────────────────────────────────────────
    if (_isDigit(ch)) {
      return _lexNumber(startLine, startCol);
    }

    // ── Identifiers, keywords, booleans ─────────────────────────────────────
    if (_isIdentStart(ch)) {
      return _lexIdent(startLine, startCol);
    }

    throw ParseError(
      line: startLine,
      column: startCol,
      message: "Unexpected character '${_escapeChar(ch)}'",
    );
  }

  Token _lexString(int startLine, int startCol) {
    final quote = _current;
    _advance(); // opening quote
    final buf = StringBuffer();

    while (_pos < _source.length && _current != quote) {
      final ch = _current;
      if (ch == '\n') {
        throw ParseError(
          line: startLine,
          column: startCol,
          message: 'Unterminated string literal',
          hint: "Close the string with $quote before the end of the line",
        );
      }
      if (ch == '\\') {
        _advance(); // consume backslash
        if (_pos >= _source.length) {
          throw ParseError(
            line: _line,
            column: _col,
            message: 'Unterminated escape sequence in string',
          );
        }
        final esc = _current;
        switch (esc) {
          case 'n':
            buf.write('\n');
          case 't':
            buf.write('\t');
          case '\\':
            buf.write('\\');
          case "'":
            buf.write("'");
          case '"':
            buf.write('"');
          case 'r':
            buf.write('\r');
          default:
            throw ParseError(
              line: _line,
              column: _col,
              message: "Unknown escape sequence '\\$esc'",
            );
        }
        _advance();
      } else if (ch == '\$') {
        // Check for string interpolation.
        if (_peek() == '{') {
          throw ParseError(
            line: _line,
            column: _col,
            message: "DSL doesn't support string interpolation — use plain literals",
            hint: 'Replace \${...} with a literal string value',
          );
        }
        // Bare '$' is just a literal character.
        buf.write(ch);
        _advance();
      } else {
        buf.write(ch);
        _advance();
      }
    }

    if (_pos >= _source.length) {
      throw ParseError(
        line: startLine,
        column: startCol,
        message: 'Unterminated string literal',
        hint: "Close the string with $quote",
      );
    }
    _advance(); // closing quote

    return Token(
      kind: TokenKind.string,
      value: buf.toString(),
      line: startLine,
      column: startCol,
    );
  }

  Token _lexNumber(int startLine, int startCol) {
    final buf = StringBuffer();
    while (_pos < _source.length && _isDigit(_current)) {
      buf.write(_current);
      _advance();
    }
    // Check for decimal point.
    if (_pos < _source.length && _current == '.' && _isDigit(_peek())) {
      buf.write('.');
      _advance();
      while (_pos < _source.length && _isDigit(_current)) {
        buf.write(_current);
        _advance();
      }
    }
    return Token(
      kind: TokenKind.number,
      value: buf.toString(),
      line: startLine,
      column: startCol,
    );
  }

  Token _lexIdent(int startLine, int startCol) {
    final buf = StringBuffer();
    while (_pos < _source.length && _isIdentContinue(_current)) {
      buf.write(_current);
      _advance();
    }
    final word = buf.toString();
    if (word == 'true' || word == 'false') {
      return Token(kind: TokenKind.bool_, value: word, line: startLine, column: startCol);
    }
    return Token(kind: TokenKind.ident, value: word, line: startLine, column: startCol);
  }

  // ── Character classification helpers ────────────────────────────────────────

  static bool _isDigit(String ch) => ch.isNotEmpty && ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;

  static bool _isIdentStart(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
  }

  static bool _isIdentContinue(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95;
  }

  static String _escapeChar(String ch) {
    if (ch == '\n') return '\\n';
    if (ch == '\t') return '\\t';
    return ch;
  }
}
