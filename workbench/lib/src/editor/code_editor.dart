import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart' as re_editor;
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import 'dsl_catalog.dart';

/// A parse-error annotation for a specific source line.
///
/// Used by [CodeEditor] to render a red error indicator in the gutter for
/// any line in [errors]. Phase 4 does not require sub-character precision —
/// a gutter marker per-line is sufficient.
class EditorErrorMark {
  final int line; // 1-based source line
  final int column; // 1-based (best-effort)
  final String message;
  final String? hint;

  const EditorErrorMark({
    required this.line,
    required this.column,
    required this.message,
    this.hint,
  });
}

/// A syntax-highlighted, optionally-editable code editor widget.
///
/// Renders [code] with Dart syntax highlighting and line numbers in a dark
/// theme that integrates with the workbench's Material 3 dark palette.
///
/// [readOnly] defaults to `true` — Phase 2 behaviour. Pass `false` to enable
/// live editing.
///
/// [onChanged] is called with the full text after every content change.
/// Only meaningful when [readOnly] is false.
///
/// [errors] is a list of [EditorErrorMark] objects. Lines in the error set
/// get a small red indicator prepended in the gutter (via a Tooltip showing
/// the error message).
class CodeEditor extends StatefulWidget {
  const CodeEditor({
    required this.code,
    this.readOnly = true,
    this.onChanged,
    this.errors = const [],
    super.key,
  });

  /// The Dart DSL source text to display.
  final String code;

  /// When true the user cannot modify the content; they can still select
  /// and copy text. Defaults to true.
  final bool readOnly;

  /// Called with the new full text on every content change.
  /// Only fired when [readOnly] is false.
  final ValueChanged<String>? onChanged;

  /// Lines that should show an error indicator in the gutter.
  /// Lines are 1-based to match [ParseError.line].
  final List<EditorErrorMark> errors;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  late re_editor.CodeLineEditingController _controller;

  // Single stable listener reference — required so we can remove it in dispose
  // without leaking on hot-reload.
  late final VoidCallback _editorListener;

  // Gutter background: slightly lighter than the editor body so it reads
  // as a distinct lane without being jarring.
  static const Color _gutterBg = Color(0xff21252e); // ~3% lighter than #1e2127
  static const Color _gutterFg = Color(0xff636d83); // muted, fades into bg
  static const Color _editorBg = Color(0xff1e2127); // slightly darker than atom-one-dark root
  static const Color _selectionColor = Color(0x553e4451); // atom-one-dark selection
  static const Color _gutterDivider = Color(0xff3e4451); // subtle divider
  static const Color _errorDot = Color(0xffff5555); // bright red for error markers

  @override
  void initState() {
    super.initState();
    _controller = re_editor.CodeLineEditingController.fromText(widget.code);
    _editorListener = () {
      widget.onChanged?.call(_controller.text);
    };
    _controller.addListener(_editorListener);
  }

  @override
  void didUpdateWidget(CodeEditor old) {
    super.didUpdateWidget(old);
    // Guard against resetting the cursor when the parent echoes back the same
    // text the user just typed (e.g. after a debounce round-trip).
    if (old.code != widget.code && _controller.text != widget.code) {
      _controller.text = widget.code;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_editorListener);
    _controller.dispose();
    super.dispose();
  }

  /// Build the set of error line numbers (1-based) for fast lookup.
  Set<int> get _errorLines => {for (final e in widget.errors) e.line};

  /// Find the [EditorErrorMark] for a given 1-based line, or null.
  EditorErrorMark? _markForLine(int line) {
    for (final e in widget.errors) {
      if (e.line == line) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final errorLines = _errorLines;

    final editor = re_editor.CodeEditor(
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
              child: _ErrorGutter(
                editingController: editingController,
                notifier: notifier,
                errorLines: errorLines,
                markForLine: _markForLine,
                gutterFg: _gutterFg,
                errorDot: _errorDot,
              ),
            ),
            Container(width: 1, color: _gutterDivider),
          ],
        );
      },
    );

    if (widget.readOnly) return editor;

    // Wrap the editor in CodeAutocomplete so DSL primitives surface as
    // suggestions whenever the user starts typing an identifier.
    return re_editor.CodeAutocomplete(
      promptsBuilder: re_editor.DefaultCodeAutocompletePromptsBuilder(
        // language: null → don't pull in Dart's built-in keyword list. The
        // DSL is a strict subset; only our catalog should be suggested.
        directPrompts: [
          for (final p in kDirectPrimitives) _DslPrompt(p),
        ],
        relatedPrompts: {
          for (final entry in kRelatedPrimitives.entries)
            entry.key: [for (final p in entry.value) _DslPrompt(p)],
        },
      ),
      viewBuilder: (context, notifier, onSelected) {
        return _AutocompleteMenu(
          notifier: notifier,
          onSelected: onSelected,
        );
      },
      child: editor,
    );
  }
}

// ─── DSL prompt adapter ───────────────────────────────────────────────────────

/// Adapts a [DslPrimitive] to re_editor's [re_editor.CodePrompt] surface.
///
/// `match` is case-sensitive `startsWith` — Dart-style — and `autocomplete`
/// returns the primitive's snippet with the placeholder selection pre-applied.
class _DslPrompt extends re_editor.CodePrompt {
  _DslPrompt(this.primitive) : super(word: primitive.name);

  final DslPrimitive primitive;

  @override
  re_editor.CodeAutocompleteResult get autocomplete => primitive.autocomplete;

  @override
  bool match(String input) => word != input && word.startsWith(input);

  @override
  bool operator ==(Object other) =>
      other is _DslPrompt && other.primitive.name == primitive.name;

  @override
  int get hashCode => primitive.name.hashCode;
}

// ─── Autocomplete popup view ─────────────────────────────────────────────────

class _AutocompleteMenu extends StatelessWidget
    implements PreferredSizeWidget {
  const _AutocompleteMenu({
    required this.notifier,
    required this.onSelected,
  });

  final ValueNotifier<re_editor.CodeAutocompleteEditingValue> notifier;
  final ValueChanged<re_editor.CodeAutocompleteResult> onSelected;

  // The popup has a fixed footprint so re_editor's overlay positioner can
  // decide whether to flip it above/below the caret. Width is generous to fit
  // the longest signature; height is sized for ~6 visible rows + the footer.
  static const double _menuWidth = 460;
  static const double _menuHeight = 260;

  @override
  Size get preferredSize => const Size(_menuWidth, _menuHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _menuWidth,
      height: _menuHeight,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        elevation: 8,
        borderRadius: BorderRadius.circular(6),
        child: ValueListenableBuilder<re_editor.CodeAutocompleteEditingValue>(
          valueListenable: notifier,
          builder: (context, value, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: value.prompts.length,
                    itemBuilder: (context, i) {
                      final prompt = value.prompts[i];
                      final primitive = prompt is _DslPrompt
                          ? prompt.primitive
                          : null;
                      final selected = i == value.index;
                      return InkWell(
                        onTap: () =>
                            onSelected(value.copyWith(index: i).autocomplete),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: selected
                              ? theme.colorScheme.primary.withValues(alpha: 0.18)
                              : null,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                child: Icon(
                                  _iconForGroup(primitive?.group),
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                prompt.word,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  primitive?.signature ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (value.prompts.isNotEmpty)
                  _DescriptionFooter(
                    primitive: value.prompts[value.index] is _DslPrompt
                        ? (value.prompts[value.index] as _DslPrompt).primitive
                        : null,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DescriptionFooter extends StatelessWidget {
  const _DescriptionFooter({required this.primitive});

  final DslPrimitive? primitive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = primitive?.description ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

IconData _iconForGroup(DslGroup? g) {
  switch (g) {
    case DslGroup.topLevel:
      return Icons.flag_outlined;
    case DslGroup.contract:
      return Icons.description_outlined;
    case DslGroup.fieldType:
      return Icons.category_outlined;
    case DslGroup.constraints:
      return Icons.rule;
    case DslGroup.posture:
      return Icons.tune;
    case DslGroup.outcomes:
      return Icons.account_tree_outlined;
    case DslGroup.handoffs:
      return Icons.send_outlined;
    case null:
      return Icons.code;
  }
}

// ── Error-aware gutter ─────────────────────────────────────────────────────────

/// A custom gutter widget that renders line numbers AND a small red dot (with
/// Tooltip) on any line that has a parse error.
///
/// Implementation choice: we use [ValueListenableBuilder] on the
/// [re_editor.CodeIndicatorValueNotifier] to know which lines are currently
/// visible (the notifier gives us a list of [CodeLineRenderParagraph], each
/// with its 0-based index and vertical offset). We map each paragraph's index
/// to a 1-based source line via [editingController.index2lineIndex], then check
/// against [errorLines].
///
/// We render a fixed-width Stack: the [re_editor.DefaultCodeLineNumber] paints
/// the numbers, and we overlay a small coloured dot + Tooltip for error lines.
class _ErrorGutter extends StatelessWidget {
  const _ErrorGutter({
    required this.editingController,
    required this.notifier,
    required this.errorLines,
    required this.markForLine,
    required this.gutterFg,
    required this.errorDot,
  });

  final re_editor.CodeLineEditingController editingController;
  final re_editor.CodeIndicatorValueNotifier notifier;
  final Set<int> errorLines;
  final EditorErrorMark? Function(int line) markForLine;
  final Color gutterFg;
  final Color errorDot;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<re_editor.CodeIndicatorValue?>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return Stack(
          children: [
            // Base: standard line numbers
            re_editor.DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: gutterFg,
              ),
            ),
            // Overlay: error dots on error lines
            if (value != null && errorLines.isNotEmpty)
              Positioned.fill(
                child: _ErrorDotOverlay(
                  paragraphs: value.paragraphs,
                  editingController: editingController,
                  errorLines: errorLines,
                  markForLine: markForLine,
                  errorDot: errorDot,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Renders small coloured dots with Tooltips at the vertical position of each
/// error line among the currently visible paragraphs.
class _ErrorDotOverlay extends StatelessWidget {
  const _ErrorDotOverlay({
    required this.paragraphs,
    required this.editingController,
    required this.errorLines,
    required this.markForLine,
    required this.errorDot,
  });

  final List<re_editor.CodeLineRenderParagraph> paragraphs;
  final re_editor.CodeLineEditingController editingController;
  final Set<int> errorLines;
  final EditorErrorMark? Function(int line) markForLine;
  final Color errorDot;

  @override
  Widget build(BuildContext context) {
    final List<Widget> dots = [];
    for (final para in paragraphs) {
      // Convert 0-based paragraph index to 1-based source line.
      final sourceLine = editingController.index2lineIndex(para.index) + 1;
      if (!errorLines.contains(sourceLine)) continue;
      final mark = markForLine(sourceLine);
      final tooltipMsg = mark == null
          ? 'Error on line $sourceLine'
          : (mark.hint != null
              ? '${mark.message}\n${mark.hint}'
              : mark.message);

      dots.add(
        Positioned(
          top: para.top,
          left: 0,
          child: Tooltip(
            message: tooltipMsg,
            child: SizedBox(
              width: 8,
              height: para.preferredLineHeight,
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: errorDot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Stack(children: dots);
  }
}
