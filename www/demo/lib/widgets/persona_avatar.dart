import 'package:flutter/material.dart';

/// Procedurally-painted persona avatar — distinct geometry per seed.
class PersonaAvatar extends StatelessWidget {
  final int seed;
  final double hue;
  final double size;

  const PersonaAvatar({
    super.key,
    required this.seed,
    required this.hue,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _AvatarPainter(seed: seed, hue: hue),
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final int seed;
  final double hue;
  _AvatarPainter({required this.seed, required this.hue});

  Color _hsl(double h, double s, double l) {
    return HSLColor.fromAHSL(1, h % 360, s, l).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c1 = _hsl(hue, 0.6, 0.65);
    final c2 = _hsl(hue + 40, 0.7, 0.55);
    final c3 = _hsl(hue + 200, 0.5, 0.35);

    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        colors: [c1, c2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final fg = Paint()..color = c3.withValues(alpha: 0.85);
    final accent = Paint()..color = c1;

    final w = size.width;
    final variant = seed % 4;
    switch (variant) {
      case 0:
        canvas.drawCircle(Offset(w * 0.5, w * 0.42), w * 0.18, fg);
        final path = Path()
          ..moveTo(w * 0.21, w)
          ..cubicTo(w * 0.21, w * 0.66, w * 0.79, w * 0.66, w * 0.79, w)
          ..close();
        canvas.drawPath(path, fg);
        break;
      case 1:
        canvas.drawCircle(Offset(w * 0.42, w * 0.46), w * 0.13, fg);
        canvas.drawCircle(
          Offset(w * 0.62, w * 0.54),
          w * 0.14,
          Paint()..color = c3.withValues(alpha: 0.6),
        );
        final path = Path()
          ..moveTo(w * 0.12, w)
          ..cubicTo(w * 0.16, w * 0.75, w * 0.84, w * 0.75, w * 0.88, w)
          ..close();
        canvas.drawPath(path, Paint()..color = c3.withValues(alpha: 0.7));
        break;
      case 2:
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.29, w * 0.29, w * 0.42, w * 0.42),
          const Radius.circular(8),
        );
        canvas.drawRRect(r, fg);
        canvas.drawCircle(Offset(w * 0.5, w * 0.46), w * 0.07, accent);
        break;
      case 3:
        final p = Path()
          ..moveTo(w * 0.5, w * 0.17)
          ..lineTo(w * 0.83, w * 0.5)
          ..lineTo(w * 0.5, w * 0.83)
          ..lineTo(w * 0.17, w * 0.5)
          ..close();
        canvas.drawPath(p, fg);
        canvas.drawCircle(Offset(w * 0.5, w * 0.5), w * 0.1, accent);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.seed != seed || old.hue != hue;
}
