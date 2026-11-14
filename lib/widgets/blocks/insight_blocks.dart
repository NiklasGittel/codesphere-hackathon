import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/ui_block.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../ui/common.dart';
import '../ui/primitives.dart';

Color severityColor(Severity s) => switch (s) {
      Severity.critical => AppColors.destructive,
      Severity.warning => AppColors.warning,
      Severity.success => AppColors.success,
      Severity.info => AppColors.chartPalette[0],
    };

// -------------------------------------------------------------- heatmap ----

class HeatmapCard extends StatelessWidget {
  const HeatmapCard({super.key, required this.block});
  final HeatmapBlock block;

  static const _good0 = Color(0xFFDCFCE7);
  static const _good1 = Color(0xFFFEF9C3);
  static const _bad0 = Color(0xFFFDBA74);
  static const _bad1 = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final all = [for (final r in block.values) ...r];
    final minV = all.isEmpty ? 0.0 : all.reduce(math.min);
    final maxV = all.isEmpty ? 1.0 : all.reduce(math.max);
    final th = block.threshold;

    Color colorFor(double v) {
      if (th == null) {
        final t = maxV == minV ? 0.0 : (v - minV) / (maxV - minV);
        return Color.lerp(AppColors.muted, AppColors.chartPalette[0], t)!;
      }
      if (v <= th) {
        final t = th == minV ? 0.0 : ((v - minV) / (th - minV)).clamp(0.0, 1.0).toDouble();
        return Color.lerp(_good0, _good1, t)!;
      }
      final t = maxV == th ? 1.0 : ((v - th) / (maxV - th)).clamp(0.0, 1.0).toDouble();
      return Color.lerp(_bad0, _bad1, t)!;
    }

    const labelW = 116.0;
    final cols = block.xLabels.length;
    return ShadCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardHeader(
          title: block.title,
          subtitle: block.subtitle,
          trailing: block.source == null ? null : ShadBadge(label: block.source!),
        ),
        const SizedBox(height: 16),
        for (var y = 0; y < block.yLabels.length; y++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              SizedBox(
                width: labelW,
                child: Text(block.yLabels[y],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: Row(children: [
                  for (var x = 0; x < cols; x++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: _Cell(
                          color: x < block.values[y].length
                              ? colorFor(block.values[y][x])
                              : AppColors.muted,
                          tooltip: x < block.values[y].length
                              ? '${block.yLabels[y]} · ${block.xLabels[x]}: ${formatValue(block.values[y][x], block.unit)}'
                              : '',
                          delay: x * 22 + y * 30,
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Row(children: [
          const SizedBox(width: labelW),
          Expanded(
            child: Row(children: [
              for (var x = 0; x < cols; x++)
                Expanded(
                  child: Text(x % 3 == 0 ? block.xLabels[x] : '',
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: AppText.small.copyWith(fontSize: 10.5)),
                ),
            ]),
          ),
        ]),
        if (th != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            _Swatch(colors: const [_good0, _good1]),
            const SizedBox(width: 6),
            Text('Below ${formatValue(th, block.unit)}', style: AppText.small),
            const SizedBox(width: 16),
            _Swatch(colors: const [_bad0, _bad1]),
            const SizedBox(width: 6),
            Text('Above ${formatValue(th, block.unit)}', style: AppText.small),
          ]),
        ],
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.color, required this.tooltip, required this.delay});
  final Color color;
  final String tooltip;
  final int delay;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 150),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 250 + delay),
          curve: Curves.easeOut,
          builder: (context, t, _) => Container(
            height: 24,
            decoration: BoxDecoration(
              color: Color.lerp(AppColors.muted, color, t),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 10,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

// ------------------------------------------------------------ waterfall ----

class WaterfallCard extends StatelessWidget {
  const WaterfallCard({super.key, required this.block});
  final WaterfallBlock block;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1.0, block.total);
    final step = total > 1500 ? 500.0 : (total > 600 ? 200.0 : 100.0);
    final ticks = [for (var t = 0.0; t <= total; t += step) t];
    return ShadCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardHeader(
          title: block.title,
          subtitle: block.subtitle,
          trailing: block.source == null ? null : ShadBadge(label: block.source!),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final nameW = math.min(230.0, box.maxWidth * 0.38);
          final trackW = box.maxWidth - nameW - 12;
          return Column(children: [
            Row(children: [
              SizedBox(width: nameW),
              const SizedBox(width: 12),
              SizedBox(
                width: trackW,
                height: 18,
                child: Stack(clipBehavior: Clip.none, children: [
                  for (final t in ticks)
                    Positioned(
                      left: trackW * t / total,
                      top: 0,
                      child: Text(formatValue(t, 'ms'), style: AppText.small.copyWith(fontSize: 10.5)),
                    ),
                ]),
              ),
            ]),
            for (var i = 0; i < block.spans.length; i++)
              _SpanRow(
                span: block.spans[i],
                total: total,
                ticks: ticks,
                nameW: nameW,
                trackW: trackW,
                index: i,
                last: i == block.spans.length - 1,
              ),
          ]);
        }),
      ]),
    );
  }
}

class _SpanRow extends StatelessWidget {
  const _SpanRow({
    required this.span,
    required this.total,
    required this.ticks,
    required this.nameW,
    required this.trackW,
    required this.index,
    required this.last,
  });
  final TraceSpan span;
  final double total;
  final List<double> ticks;
  final double nameW;
  final double trackW;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = providerInfo(span.provider);
    final color = span.highlight ? AppColors.destructive : p.color.withAlpha(210);
    final left = trackW * span.start / total;
    final width = math.max(3.0, trackW * span.duration / total);
    // Label after the bar, before it, or inside it (for very wide bars).
    final fitsAfter = left + width + 64 <= trackW;
    final fitsBefore = left >= 64;
    final inside = !fitsAfter && !fitsBefore;
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: span.highlight ? const Color(0xFFFEF2F2) : null,
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F1F3))),
      ),
      child: Row(children: [
        SizedBox(
          width: nameW,
          child: Padding(
            padding: EdgeInsets.only(left: 4.0 + span.depth * 14),
            child: Row(children: [
              Dot(color: p.color, size: 7),
              const SizedBox(width: 8),
              Expanded(
                child: Text(span.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(
                        size: 12,
                        color: span.highlight ? AppColors.destructive : AppColors.foreground,
                        weight: span.highlight ? FontWeight.w600 : FontWeight.w400)),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: trackW,
          height: 32,
          child: Stack(clipBehavior: Clip.none, children: [
            for (final t in ticks)
              Positioned(
                left: trackW * t / total,
                top: 0,
                bottom: 0,
                child: Container(width: 1, color: const Color(0xFFF1F1F3)),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + index * 90),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Positioned(
                left: left,
                top: 9,
                child: Container(
                  width: width * t,
                  height: 14,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
            Positioned(
              left: fitsAfter ? left + width + 6 : null,
              right: fitsAfter
                  ? null
                  : (inside ? trackW - (left + width) + 6 : trackW - left + 6),
              top: 8,
              child: Text(formatValue(span.duration, 'ms'),
                  style: AppText.mono(
                      size: 11,
                      color: inside
                          ? Colors.white
                          : (span.highlight ? AppColors.destructive : AppColors.mutedForeground),
                      weight: span.highlight || inside ? FontWeight.w600 : FontWeight.w400)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// --------------------------------------------------------------- funnel ----

class FunnelCard extends StatelessWidget {
  const FunnelCard({super.key, required this.block});
  final FunnelBlock block;

  @override
  Widget build(BuildContext context) {
    final steps = block.steps;
    final maxV = steps.fold<double>(
        0, (m, s) => math.max(m, math.max(s.value, s.compare ?? 0)));
    return ShadCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardHeader(
          title: block.title,
          subtitle: block.subtitle,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _Legend(color: AppColors.primary, label: block.valueLabel),
            if (block.compareLabel != null) ...[
              const SizedBox(width: 12),
              _Legend(color: AppColors.border, label: block.compareLabel!),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) _Conversion(prev: steps[i - 1], cur: steps[i]),
          _FunnelRow(step: steps[i], maxV: maxV, index: i, bad: i > 0 && _dropped(steps[i - 1], steps[i])),
        ],
      ]),
    );
  }

  static bool _dropped(FunnelStep a, FunnelStep b) {
    if (a.compare == null || b.compare == null || a.value == 0 || a.compare == 0) return false;
    return (b.compare! / a.compare!) - (b.value / a.value) > 0.05;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: AppText.small),
      ]);
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow({required this.step, required this.maxV, required this.index, required this.bad});
  final FunnelStep step;
  final double maxV;
  final int index;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final frac = maxV == 0 ? 0.0 : step.value / maxV;
    final cmpFrac = (step.compare == null || maxV == 0) ? 0.0 : step.compare! / maxV;
    final change = (step.compare == null || step.compare == 0) ? null : step.value / step.compare! - 1;
    return Row(children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 700 + index * 120),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SizedBox(
              height: 36,
              child: Stack(children: [
                Container(
                  width: box.maxWidth * cmpFrac * t,
                  decoration: BoxDecoration(
                      color: AppColors.muted,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                ),
                Container(
                  width: box.maxWidth * frac * t,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                      color: bad ? AppColors.destructive : AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(step.label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      SizedBox(
        width: 74,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(groupThousands(step.value),
              style: AppText.mono(size: 13, color: AppColors.foreground, weight: FontWeight.w600)),
          if (change != null)
            Text('${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(1)}%',
                style: AppText.mono(
                    size: 11,
                    color: change < -0.05 ? AppColors.destructive : AppColors.mutedForeground)),
        ]),
      ),
    ]);
  }
}

class _Conversion extends StatelessWidget {
  const _Conversion({required this.prev, required this.cur});
  final FunnelStep prev;
  final FunnelStep cur;

  @override
  Widget build(BuildContext context) {
    final rate = prev.value == 0 ? 0.0 : cur.value / prev.value;
    final was = (prev.compare == null || cur.compare == null || prev.compare == 0)
        ? null
        : cur.compare! / prev.compare!;
    final bad = was != null && was - rate > 0.05;
    final color = bad ? AppColors.destructive : AppColors.mutedForeground;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 0, 5),
      child: Row(children: [
        Icon(Icons.south_rounded, size: 13, color: color),
        const SizedBox(width: 6),
        Text('${(rate * 100).toStringAsFixed(1)}% continue',
            style: TextStyle(fontSize: 12, color: color, fontWeight: bad ? FontWeight.w600 : FontWeight.w400)),
        if (was != null) ...[
          const SizedBox(width: 6),
          Text('(was ${(was * 100).toStringAsFixed(1)}%)', style: AppText.small.copyWith(fontSize: 11.5)),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------- timeline ----

class TimelineCard extends StatelessWidget {
  const TimelineCard({super.key, required this.block});
  final TimelineBlock block;

  @override
  Widget build(BuildContext context) => ShadCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CardHeader(title: block.title, subtitle: block.subtitle),
          const SizedBox(height: 18),
          for (var i = 0; i < block.events.length; i++)
            _TimelineRow(event: block.events[i], last: i == block.events.length - 1, index: i),
        ]),
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.last, required this.index});
  final TimelineEvent event;
  final bool last;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = event.severity == Severity.info ? AppColors.borderStrong : severityColor(event.severity);
    final s = severityStyle(event.severity);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 140),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(12 * (1 - t), 0), child: child),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            width: 50,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(event.time,
                  style: AppText.mono(size: 12, color: AppColors.foreground, weight: FontWeight.w500)),
            ),
          ),
          SizedBox(
            width: 22,
            child: Column(children: [
              const SizedBox(height: 3),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: event.severity == Severity.info ? AppColors.background : s.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: c, width: 2.5),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1.5, margin: const EdgeInsets.only(top: 3), color: AppColors.border),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(event.title,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: event.severity == Severity.critical ? s.fg : AppColors.foreground)),
                  ),
                  if (event.provider != null) ...[
                    const SizedBox(width: 8),
                    ProviderBadge(provider: event.provider!),
                  ],
                ]),
                if (event.detail != null) ...[
                  const SizedBox(height: 3),
                  RichMarkdownText(event.detail!, style: AppText.muted.copyWith(fontSize: 13, height: 1.45)),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// --------------------------------------------------------------- gauges ----

class GaugesView extends StatelessWidget {
  const GaugesView({super.key, required this.block});
  final GaugesBlock block;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < block.items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _GaugeTile(item: block.items[i])),
        ],
      ]);
}

class _GaugeTile extends StatelessWidget {
  const _GaugeTile({required this.item});
  final GaugeItem item;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(item.severity);
    return ShadCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(children: [
        Text(item.label, style: AppText.muted, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        SizedBox(
          height: 84,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: item.value),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _GaugePainter(v, color))),
              Align(
                alignment: const Alignment(0, 0.9),
                child: Text(item.display,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
              ),
            ]),
          ),
        ),
        if (item.caption != null) ...[
          const SizedBox(height: 8),
          Text(item.caption!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: item.severity == Severity.info ? AppColors.mutedForeground : color)),
        ],
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final r = math.min(size.width / 2, size.height) - stroke / 2 - 2;
    final center = Offset(size.width / 2, size.height - 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    final base = Paint()
      ..color = AppColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    if (value > 0) {
      canvas.drawArc(rect, math.pi, math.pi * value, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.value != value || old.color != color;
}

// ------------------------------------------------------------ follow-ups ----

class FollowUpsView extends StatelessWidget {
  const FollowUpsView({super.key, required this.block, required this.onAsk});
  final FollowUpsBlock block;
  final void Function(FollowUpsBlock, String) onAsk;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((block.title ?? 'Dig deeper').toUpperCase(), style: AppText.label.copyWith(fontSize: 10.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in block.questions)
            _QuestionChip(
              text: q,
              asked: block.asked.contains(q),
              onTap: () => onAsk(block, q),
            ),
        ]),
      ]);
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.text, required this.asked, required this.onTap});
  final String text;
  final bool asked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: asked ? AppColors.muted : (hovered ? AppColors.subtle : AppColors.background),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hovered ? AppColors.borderStrong : AppColors.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(asked ? Icons.check_rounded : Icons.auto_awesome_outlined,
                size: 13, color: asked ? AppColors.success : AppColors.mutedForeground),
            const SizedBox(width: 7),
            Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: asked ? AppColors.mutedForeground : AppColors.foreground)),
          ]),
        ),
      );
}
