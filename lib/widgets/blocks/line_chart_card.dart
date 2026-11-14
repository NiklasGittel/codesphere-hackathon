import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ui_block.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../ui/common.dart';
import '../ui/primitives.dart';

class LineChartCard extends StatelessWidget {
  const LineChartCard({super.key, required this.block});
  final LineChartBlock block;

  Color _color(int i) =>
      block.series[i].color ??
      AppColors.chartPalette[i % AppColors.chartPalette.length];

  @override
  Widget build(BuildContext context) => ShadCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardHeader(
              title: block.title,
              subtitle: block.subtitle,
              trailing:
                  block.source == null ? null : ShadBadge(label: block.source!),
            ),
            if (block.series.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 16, children: [
                for (var i = 0; i < block.series.length; i++)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 10,
                        height: 3,
                        decoration: BoxDecoration(
                            color: _color(i),
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text(block.series[i].name, style: AppText.small),
                  ]),
              ]),
            ],
            const SizedBox(height: 12),
            SizedBox(height: 220, child: _InteractiveChart(block: block, color: _color)),
          ],
        ),
      );
}

class _InteractiveChart extends StatefulWidget {
  const _InteractiveChart({required this.block, required this.color});
  final LineChartBlock block;
  final Color Function(int) color;

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  int? _hover;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final geo = _Geometry(widget.block, Size(box.maxWidth, box.maxHeight));
        return MouseRegion(
          onHover: (e) => setState(() => _hover = geo.indexAt(e.localPosition.dx)),
          onExit: (_) => setState(() => _hover = null),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LinePainter(
                        block: widget.block,
                        geo: geo,
                        progress: t,
                        hover: _hover,
                        color: widget.color),
                  ),
                ),
                if (_hover != null) _tooltip(geo, _hover!),
              ],
            ),
          ),
        );
      });

  Widget _tooltip(_Geometry geo, int i) {
    const w = 170.0;
    final x = geo.xFor(i);
    final left = x + 14 + w > geo.size.width ? x - 14 - w : x + 14;
    final b = widget.block;
    return Positioned(
      left: left,
      top: 4,
      child: IgnorePointer(
        child: Container(
          width: w,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(i < b.labels.length ? b.labels[i] : '#$i',
                  style: AppText.small.copyWith(
                      fontWeight: FontWeight.w500, color: AppColors.foreground)),
              const SizedBox(height: 6),
              for (var s = 0; s < b.series.length; s++)
                if (i < b.series[s].values.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Dot(color: widget.color(s), size: 7),
                      const SizedBox(width: 6),
                      Expanded(child: Text(b.series[s].name, style: AppText.small)),
                      Text(formatValue(b.series[s].values[i], b.unit),
                          style: AppText.mono(
                              size: 12,
                              color: AppColors.foreground,
                              weight: FontWeight.w600)),
                    ]),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Geometry {
  _Geometry(this.block, this.size) {
    final all = <double>[
      for (final s in block.series) ...s.values,
      if (block.threshold != null) block.threshold!,
    ];
    final rawMax = all.isEmpty ? 1.0 : all.reduce(math.max);
    maxY = _niceCeil(rawMax * 1.08);
    plot = Rect.fromLTRB(44, 14, size.width - 6, size.height - 22);
  }

  final LineChartBlock block;
  final Size size;
  late final double maxY;
  late final Rect plot;

  int get count => block.labels.isNotEmpty
      ? block.labels.length
      : (block.series.isEmpty ? 0 : block.series.first.values.length);

  double xFor(num i) =>
      count <= 1 ? plot.left : plot.left + plot.width * i / (count - 1);

  double yFor(double v) => plot.bottom - plot.height * (v / maxY);

  int? indexAt(double dx) {
    if (count == 0) return null;
    final r = ((dx - plot.left) / plot.width * (count - 1)).round();
    return r.clamp(0, count - 1).toInt();
  }

  static double _niceCeil(double v) {
    if (v <= 0) return 1;
    final e = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final f = v / e;
    final nf = f <= 1
        ? 1.0
        : f <= 2
            ? 2.0
            : f <= 2.5
                ? 2.5
                : f <= 5
                    ? 5.0
                    : 10.0;
    return nf * e;
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.block,
    required this.geo,
    required this.progress,
    required this.hover,
    required this.color,
  });

  final LineChartBlock block;
  final _Geometry geo;
  final double progress;
  final int? hover;
  final Color Function(int) color;

  void _text(Canvas c, String s, Offset anchor,
      {Alignment align = Alignment.center,
      Color color = AppColors.mutedForeground,
      double size = 11,
      FontWeight weight = FontWeight.w400}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        c,
        Offset(anchor.dx - tp.width * (align.x + 1) / 2,
            anchor.dy - tp.height * (align.y + 1) / 2));
  }

  void _dashed(Canvas c, Offset a, Offset b, Paint p) {
    const dash = 4.0, gap = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = math.min(d + dash, total);
      c.drawLine(a + dir * d, a + dir * end, p);
      d += dash + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geo.plot;
    final n = geo.count;
    if (n == 0) return;

    // Grid + y axis.
    for (var i = 0; i <= 4; i++) {
      final v = geo.maxY * i / 4;
      final y = geo.yFor(v);
      canvas.drawLine(
          Offset(plot.left, y),
          Offset(plot.right, y),
          Paint()
            ..color = i == 0 ? AppColors.border : const Color(0xFFF1F1F3)
            ..strokeWidth = 1);
      _text(canvas, formatAxis(v, block.unit), Offset(plot.left - 8, y),
          align: Alignment.centerRight);
    }

    // X labels (~6).
    final step = math.max(1, (n / 6).ceil());
    for (var i = 0; i < n && i < block.labels.length; i += step) {
      _text(canvas, block.labels[i], Offset(geo.xFor(i), plot.bottom + 6),
          align: Alignment.topCenter);
    }

    // Highlighted region (e.g. "after deploy").
    final from = block.highlightFrom;
    if (from != null && from < n && n > 1) {
      final style = severityStyle(block.highlightSeverity);
      final half = plot.width / (n - 1) / 2;
      final x0 = math.max(plot.left, geo.xFor(from) - half);
      canvas.drawRect(Rect.fromLTRB(x0, plot.top, plot.right, plot.bottom),
          Paint()..color = style.fg.withAlpha(14));
      _dashed(canvas, Offset(x0, plot.top), Offset(x0, plot.bottom),
          Paint()
            ..color = style.fg.withAlpha(120)
            ..strokeWidth = 1);
      if (block.highlightLabel != null) {
        _text(canvas, block.highlightLabel!, Offset(x0 + 6, plot.top + 4),
            align: Alignment.topLeft,
            color: style.fg,
            size: 10.5,
            weight: FontWeight.w600);
      }
    }

    // Threshold.
    final th = block.threshold;
    if (th != null) {
      final y = geo.yFor(th);
      _dashed(canvas, Offset(plot.left, y), Offset(plot.right, y),
          Paint()
            ..color = AppColors.destructive.withAlpha(150)
            ..strokeWidth = 1.2);
      if (block.thresholdLabel != null) {
        _text(canvas, block.thresholdLabel!, Offset(plot.right - 2, y - 3),
            align: Alignment.bottomRight,
            color: AppColors.destructive,
            size: 10.5,
            weight: FontWeight.w500);
      }
    }

    // Series, revealed left to right.
    canvas.save();
    canvas.clipRect(
        Rect.fromLTRB(0, 0, plot.left + plot.width * progress + 2, size.height));
    for (var s = block.series.length - 1; s >= 0; s--) {
      final values = block.series[s].values;
      if (values.isEmpty) continue;
      final c = color(s);
      final pts = [
        for (var i = 0; i < values.length; i++)
          Offset(geo.xFor(i), geo.yFor(values[i]))
      ];
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final p0 = pts[i - 1], p1 = pts[i];
        final mx = (p0.dx + p1.dx) / 2;
        line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
      }
      if (s == 0) {
        final fill = Path.from(line)
          ..lineTo(pts.last.dx, plot.bottom)
          ..lineTo(pts.first.dx, plot.bottom)
          ..close();
        canvas.drawPath(
            fill,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c.withAlpha(46), c.withAlpha(0)],
              ).createShader(plot));
      }
      canvas.drawPath(
          line,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = s == 0 ? 2 : 1.5
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);
    }
    canvas.restore();

    // Hover crosshair.
    final h = hover;
    if (h != null) {
      final x = geo.xFor(h);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom),
          Paint()
            ..color = AppColors.borderStrong
            ..strokeWidth = 1);
      for (var s = 0; s < block.series.length; s++) {
        final values = block.series[s].values;
        if (h >= values.length) continue;
        final p = Offset(x, geo.yFor(values[h]));
        canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
            p,
            4.5,
            Paint()
              ..color = color(s)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.progress != progress || old.hover != hover || old.block != block;
}
