import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart' as re_editor;
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

/// A syntax-highlighted, read-only (Phase 2) code editor widget.
///
/// Renders [code] with Dart syntax highlighting and line numbers in a dark
/// theme that integrates with the workbench's Material 3 dark palette.
///
/// [readOnly] defaults to `true` — Phase 4 will pass `false` to enable
/// live editing. The editor remains selectable and copyable regardless of
/// [readOnly].
class CodeEditor extends StatefulWidget {
  const CodeEditor({
    required this.code,
    this.readOnly = true,
    super.key,
  });

  /// The Dart DSL source text to display.
  final String code;

  /// When true the user cannot modify the content; they can still select
  /// and copy text. Phase 2 always passes true.
  final bool readOnly;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late re_editor.CodeLineEditingController _controller;

  // Gutter background: slightly lighter than the editor body so it reads
  // as a distinct lane without being jarring.
  static const Color _gutterBg = Color(0xff21252e); // ~3% lighter than #1e2127
  static const Color _gutterFg = Color(0xff636d83); // muted, fades into bg
  static const Color _editorBg = Color(0xff1e2127); // slightly darker than atom-one-dark root
  static const Color _selectionColor = Color(0x553e4451); // atom-one-dark selection
  static const Color _gutterDivider = Color(0xff3e4451); // subtle divider

  @override
  void initState() {
    super.initState();
    _controller = re_editor.CodeLineEditingController.fromText(widget.code);
  }

  @override
  void didUpdateWidget(CodeEditor old) {
    super.didUpdateWidget(old);
    if (old.code != widget.code) {
      _controller.text = widget.code;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return re_editor.CodeEditor(
      controller: _controller,
      readOnly: widget.readOnly,
      showCursorWhenReadOnly: false,
      wordWrap: false,
      style: re_editor.CodeEditorStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        fontFamilyFallback: const [
          'Courier New',
          'Courier',
          'DejaVu Sans Mono',
        ],
        fontHeight: 1.5,
        backgroundColor: _editorBg,
        selectionColor: _selectionColor,
        codeTheme: re_editor.CodeHighlightTheme(
          languages: {
            'dart': re_editor.CodeHighlightThemeMode(mode: langDart),
          },
          theme: atomOneDarkTheme,
        ),
      ),
      indicatorBuilder: (
        context,
        editingController,
        chunkController,
        notifier,
      ) {
        return Row(
          children: [
            Container(
              color: _gutterBg,
              child: re_editor.DefaultCodeLineNumber(
                controller: editingController,
                notifier: notifier,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                  color: _gutterFg,
                ),
              ),
            ),
            Container(width: 1, color: _gutterDivider),
          ],
        );
      },
    );
  }
}
