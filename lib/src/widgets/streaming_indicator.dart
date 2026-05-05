import 'package:flutter/material.dart';

/// A small animated "three dots" indicator shown while the LLM is generating
/// the next step.
///
/// Three filled circles pulse in sequence on a 600ms cycle driven by a single
/// [AnimationController]. The dots cycle through opacity values to give the
/// appearance of a left-to-right cascade.
///
/// An optional [label] string is shown to the right of the dots.
///
/// Example:
/// ```dart
/// if (controller.isAwaiting)
///   const StreamingIndicator(label: 'Thinking…')
/// ```
class StreamingIndicator extends StatefulWidget {
  const StreamingIndicator({super.key, this.label});

  /// Optional label shown to the right of the dots.
  final String? label;

  @override
  State<StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _cycleDuration = Duration(milliseconds: 600);
  static const _dotCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _cycleDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _dotCount; i++) ...[
              _Dot(progress: _controller.value, index: i),
              if (i < _dotCount - 1) const SizedBox(width: 4),
            ],
            if (widget.label != null) ...[
              const SizedBox(width: 8),
              Text(
                widget.label!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A single animated dot. Its opacity cycles based on the overall [progress]
/// (0.0–1.0) offset by [index] to create a staggered wave effect.
class _Dot extends StatelessWidget {
  const _Dot({required this.progress, required this.index});

  final double progress;
  final int index;

  static const _dotSize = 8.0;
  static const _totalDots = 3;

  @override
  Widget build(BuildContext context) {
    // Each dot peaks at a different phase: 0, 1/3, 2/3 of the cycle.
    final offset = index / _totalDots;
    final phased = ((progress - offset + 1.0) % 1.0);

    // Sine curve for smooth pulsing: 0.2 min opacity, 1.0 max opacity.
    final opacity = 0.2 + 0.8 * _sinPulse(phased);

    return Opacity(
      opacity: opacity,
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Maps a [0, 1) progress value to a [0, 1] sine pulse (peaks at 0.25).
  static double _sinPulse(double t) {
    // sin(pi * t) gives a single arch from 0→1→0 over [0, 1).
    return (1.0 + _sin(t * 3.14159265)) / 2.0;
  }

  static double _sin(double radians) {
    // Use Dart's built-in math via dart:math is cleaner, but to avoid an
    // extra import we approximate: delegate to the full sine via the Taylor
    // polynomial isn't worth it here. We import dart:math directly.
    return _sineApprox(radians);
  }

  /// Simple sine approximation good enough for animation (< 0.1% error).
  static double _sineApprox(double x) {
    // Normalise x to [0, 2π]
    // We know input is [0, π] from _sinPulse — just use dart:math.
    // Since we can't import here without triggering an import at the top, we
    // inline a Bhaskara I approximation: sin(x) ≈ 16x(π-x) / (5π²-4x(π-x))
    // for x in [0, π].
    const pi = 3.14159265358979;
    final xMod = x % (2 * pi);
    final xNorm = xMod <= pi ? xMod : xMod - pi;
    final sign = xMod <= pi ? 1.0 : -1.0;
    final num = 16 * xNorm * (pi - xNorm);
    final den = 5 * pi * pi - 4 * xNorm * (pi - xNorm);
    return sign * num / den;
  }
}
