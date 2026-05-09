import 'package:flutter/material.dart';

/// A horizontal split view with a draggable divider.
///
/// Renders [left] and [right] side by side. The divider can be dragged to
/// resize the split ratio, clamped to `[0.15, 0.85]`. Double-clicking the
/// divider snaps the ratio back to 50/50.
///
/// The ratio is maintained as a fraction of the total available width so that
/// resizing the window preserves the proportional split.
class SplitView extends StatefulWidget {
  const SplitView({
    required this.left,
    required this.right,
    this.initialRatio = 0.5,
    this.dividerWidth = 6.0,
    super.key,
  });

  /// The widget shown in the left pane.
  final Widget left;

  /// The widget shown in the right pane.
  final Widget right;

  /// Initial split ratio in the range `[0.15, 0.85]`.
  final double initialRatio;

  /// Width of the drag handle divider in logical pixels.
  final double dividerWidth;

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  late double _ratio;

  static const double _minRatio = 0.15;
  static const double _maxRatio = 0.85;

  @override
  void initState() {
    super.initState();
    _ratio = widget.initialRatio.clamp(_minRatio, _maxRatio);
  }

  void _onDragUpdate(DragUpdateDetails details, double totalWidth) {
    final effectiveWidth = totalWidth - widget.dividerWidth;
    if (effectiveWidth <= 0) return;
    setState(() {
      _ratio = (_ratio + details.delta.dx / effectiveWidth)
          .clamp(_minRatio, _maxRatio);
    });
  }

  void _snapToCenter() {
    setState(() {
      _ratio = 0.5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftWidth =
            (totalWidth - widget.dividerWidth) * _ratio;
        final rightWidth =
            (totalWidth - widget.dividerWidth) * (1.0 - _ratio);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left pane
            SizedBox(
              width: leftWidth,
              child: widget.left,
            ),

            // Divider / drag handle
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) =>
                    _onDragUpdate(details, totalWidth),
                onDoubleTap: _snapToCenter,
                child: SizedBox(
                  width: widget.dividerWidth,
                  child: VerticalDivider(
                    width: widget.dividerWidth,
                    thickness: 2,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),

            // Right pane
            SizedBox(
              width: rightWidth,
              child: widget.right,
            ),
          ],
        );
      },
    );
  }
}
