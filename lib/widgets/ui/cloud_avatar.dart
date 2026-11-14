import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';

/// Stratus' avatar: a small cloud character.
///
/// Minimal: three puffs and two dot eyes. While [thinking] the puffs breathe
/// out of phase, the cloud floats and the eyes drift and blink.
class CloudAvatar extends StatefulWidget {
  const CloudAvatar({super.key, this.thinking = false, this.size = 30});
  final bool thinking;
  final double size;

  @override
  State<CloudAvatar> createState() => _CloudAvatarState();
}

class _CloudAvatarState extends State<CloudAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void initState() {
    super.initState();
    if (widget.thinking) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant CloudAvatar old) {
    super.didUpdateWidget(old);
    if (widget.thinking && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.thinking && _ctrl.isAnimating) {
      // Finish gently into the resting pose.
      _ctrl.animateTo(1, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            painter: _CloudPainter(t: _ctrl.value, thinking: widget.thinking),
          ),
        ),
      );
}

class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.t, required this.thinking});
  final double t;
  final bool thinking;

  // Three puffs (x, y, radius) on a 30×30 grid, with a flat base.
  static const _puffs = [(10.0, 17.0, 5.2), (16.0, 13.5, 6.8), (21.5, 17.0, 4.8)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 30;
    final bob = thinking ? math.sin(t * 2 * math.pi) * 1.2 : 0.0;

    canvas.save();
    canvas.scale(s);
    canvas.translate(0, bob);

    final body = Paint()..color = AppColors.primary;
    // Each puff breathes slightly out of phase while thinking.
    for (var i = 0; i < _puffs.length; i++) {
      final (x, y, r) = _puffs[i];
      final pulse = thinking ? 1 + 0.09 * math.sin((t + i / 3) * 2 * math.pi) : 1.0;
      canvas.drawCircle(Offset(x, y), r * pulse, body);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(6, 15, 25, 22.2), const Radius.circular(3.6)), body);

    // Two dot eyes that drift and blink while thinking.
    final look = thinking ? math.sin(t * 2 * math.pi) * 0.9 : 0.0;
    final blink = thinking && t > 0.9 && t < 0.96 ? 0.2 : 1.0;
    final eye = Paint()..color = Colors.white;
    for (final x in [13.4, 18.6]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + look, 17.6), width: 2.2, height: 2.2 * blink),
        eye,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => old.t != t || old.thinking != thinking;
}
