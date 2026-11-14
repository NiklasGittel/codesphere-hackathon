import 'dart:math' as math;

import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.height = 36});
  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => CustomPaint(
            size: Size.infinite,
            painter: _SparkPainter(values, color, t),
          ),
        ),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.progress);
  final List<double> values;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final minV = values.reduce(math.min);
    final range = (maxV - minV) == 0 ? 1 : maxV - minV;
    Offset pt(int i) => Offset(
          size.width * i / (values.length - 1),
          3 + (size.height - 6) * (1 - (values[i] - minV) / range),
        );
    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = pt(i - 1), p1 = pt(i);
      final mx = (p0.dx + p1.dx) / 2;
      line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress + 1, size.height));
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withAlpha(50), color.withAlpha(0)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);
    canvas.restore();
    final last = pt(values.length - 1);
    if (progress > 0.98) {
      canvas.drawCircle(last, 3, Paint()..color = color);
      canvas.drawCircle(last, 6, Paint()..color = color.withAlpha(40));
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.progress != progress || old.values != values;
}
