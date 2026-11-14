import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/ui_block.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../ui/common.dart';
import '../ui/primitives.dart';

// ---------------------------------------------------------------- stats ----

class StatsView extends StatelessWidget {
  const StatsView({super.key, required this.block});
  final StatsBlock block;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 12.0;
        final n = math.max(1, block.items.length);
        final cols = math.max(1, math.min(n, ((box.maxWidth + gap) / (150 + gap)).floor()));
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in block.items) SizedBox(width: w, child: _StatTile(item: item)),
          ],
        );
      });
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.item});
  final StatItem item;

  @override
  Widget build(BuildContext context) {
    final deltaColor = switch (item.good) {
      true => AppColors.success,
      false => AppColors.destructive,
      null => AppColors.mutedForeground,
    };
    return ShadCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: AppText.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(item.value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: AppColors.foreground)),
          if (item.delta != null) ...[
            const SizedBox(height: 4),
            Text(item.delta!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: deltaColor)),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ bar chart ----

class BarChartCard extends StatelessWidget {
  const BarChartCard({super.key, required this.block});
  final BarChartBlock block;

  @override
  Widget build(BuildContext context) {
    final max = block.bars.fold<double>(0, (m, b) => math.max(m, b.value));
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader(
            title: block.title,
            subtitle: block.subtitle,
            trailing: block.source == null ? null : ShadBadge(label: block.source!),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final labelW = math.min(200.0, box.maxWidth * 0.36);
            return Column(children: [
              for (var i = 0; i < block.bars.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                  child: _BarRow(
                    bar: block.bars[i],
                    fraction: max == 0 ? 0 : block.bars[i].value / max,
                    unit: block.unit,
                    labelWidth: labelW,
                    delay: i,
                  ),
                ),
            ]);
          }),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.bar,
    required this.fraction,
    required this.unit,
    required this.labelWidth,
    required this.delay,
  });
  final BarItem bar;
  final double fraction;
  final String unit;
  final double labelWidth;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final color = bar.highlight ? AppColors.destructive : AppColors.chartPalette[0];
    return Row(children: [
      SizedBox(
        width: labelWidth,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bar.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (bar.sublabel != null)
            Text(bar.sublabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(fontSize: 11.5)),
        ]),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: Duration(milliseconds: 700 + delay * 80),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Stack(children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                    color: AppColors.muted, borderRadius: BorderRadius.circular(5)),
              ),
              Container(
                width: box.maxWidth * v,
                height: 10,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(5)),
              ),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 76,
        child: Text(formatValue(bar.value, unit),
            textAlign: TextAlign.right,
            style: AppText.mono(
                size: 12.5,
                color: bar.highlight ? AppColors.destructive : AppColors.foreground,
                weight: FontWeight.w500)),
      ),
    ]);
  }
}

// -------------------------------------------------------------- finding ----

class FindingView extends StatelessWidget {
  const FindingView({super.key, required this.block});
  final FindingBlock block;

  @override
  Widget build(BuildContext context) {
    final s = severityStyle(block.severity);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: s.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(s.icon, size: 18, color: s.fg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(block.title,
                style: AppText.title.copyWith(
                    color: block.severity == Severity.info ? AppColors.foreground : s.fg)),
            const SizedBox(height: 4),
            RichMarkdownText(block.body,
                style: AppText.body.copyWith(fontSize: 13.5, height: 1.55)),
            if (block.evidence.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('EVIDENCE', style: AppText.label.copyWith(fontSize: 10.5)),
              const SizedBox(height: 4),
              for (final e in block.evidence)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 8),
                      child: Dot(color: s.fg.withAlpha(150), size: 4),
                    ),
                    Expanded(child: Text(e, style: AppText.body.copyWith(fontSize: 13))),
                  ]),
                ),
            ],
          ]),
        ),
      ]),
    );
  }
}
