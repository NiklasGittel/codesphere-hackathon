import 'package:flutter/material.dart';

import '../data/start_data.dart';
import '../models/ui_block.dart';
import '../theme.dart';
import 'start_page.dart' show OpenTopic;
import 'ui/common.dart';
import 'ui/primitives.dart';
import 'ui/sparkline.dart';

// ---------------------------------------------------------- shared bits ----

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({required this.title, required this.subtitle, required this.children, this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
                  ]),
                ),
                if (trailing != null) trailing!,
              ]),
              const SizedBox(height: 24),
              ...children,
            ]),
          ),
        ),
      );
}

class _Table extends StatelessWidget {
  const _Table({required this.header, required this.rows});
  final Widget header;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: AppColors.subtle,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: header,
          ),
          for (final r in rows) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            r,
          ],
        ]),
      );
}

Text _head(String s, {TextAlign align = TextAlign.left}) =>
    Text(s.toUpperCase(), textAlign: align, style: AppText.label.copyWith(fontSize: 10.5));

class _Row extends StatelessWidget {
  const _Row({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: hovered ? AppColors.subtle : AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Expanded(child: child),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: hovered ? AppColors.foreground : AppColors.borderStrong),
          ]),
        ),
      );
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in options)
            HoverBuilder(
              onTap: () => onChanged(o),
              builder: (context, hovered) => AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: o == value ? AppColors.background : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: o == value
                      ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
                      : null,
                ),
                child: Text(o,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: o == value || hovered ? AppColors.foreground : AppColors.mutedForeground)),
              ),
            ),
        ]),
      );
}

Widget _logos(List<String> providers) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (final p in providers)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Tooltip(message: providerInfo(p).name, child: ProviderLogo(provider: p, size: 16)),
        ),
    ]);

Widget _severity(Severity s, {bool resolved = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
      Dot(color: resolved ? AppColors.borderStrong : severityStyle(s).fg, size: 7),
      const SizedBox(width: 8),
      Text(
        resolved ? 'Resolved' : (s == Severity.critical ? 'Critical' : 'Warning'),
        style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: resolved ? AppColors.mutedForeground : severityStyle(s).fg),
      ),
    ]);

// ------------------------------------------------------------ incidents ----

class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key, required this.onOpen});
  final OpenTopic onOpen;

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final showOpen = _filter != 'Resolved';
    final showResolved = _filter != 'Open';
    return _PageScaffold(
      title: 'Incidents',
      subtitle: '${incidents.length} open · ${resolvedIncidents.length} resolved in the last 7 days',
      trailing: _Segmented(
        options: const ['All', 'Open', 'Resolved'],
        value: _filter,
        onChanged: (v) => setState(() => _filter = v),
      ),
      children: [
        LayoutBuilder(builder: (context, box) {
          final compact = box.maxWidth < 760;
          return _Table(
            header: _IncidentCols(
              compact: compact,
              severity: _head('Status'),
              title: _head('Incident'),
              providers: _head('Providers'),
              trend: _head('Last 24 h'),
              time: _head('Started'),
              impact: _head('Impact', align: TextAlign.right),
            ),
            rows: [
              if (showOpen)
                for (final i in incidents)
                  _Row(
                    onTap: () => widget.onOpen(i.title, i.id),
                    child: _IncidentCols(
                      compact: compact,
                      severity: _severity(i.severity),
                      title: _TitleCell(i.title, i.summary),
                      providers: _logos(i.providers),
                      trend: Sparkline(values: i.trend, color: severityStyle(i.severity).fg, height: 26),
                      time: Text('${i.since} ago', style: AppText.small),
                      impact: _ImpactCell(i.impact, i.impactLabel),
                    ),
                  ),
              if (showResolved)
                for (final r in resolvedIncidents)
                  _Row(
                    onTap: () => widget.onOpen(r.title, r.id),
                    child: _IncidentCols(
                      compact: compact,
                      severity: _severity(r.severity, resolved: true),
                      title: _TitleCell(r.title, r.summary, muted: true),
                      providers: _logos(r.providers),
                      trend: const SizedBox(),
                      time: Text(r.resolved, style: AppText.small),
                      impact: _ImpactCell(r.duration, 'duration', muted: true),
                    ),
                  ),
            ],
          );
        }),
      ],
    );
  }
}

class _IncidentCols extends StatelessWidget {
  const _IncidentCols({
    required this.compact,
    required this.severity,
    required this.title,
    required this.providers,
    required this.trend,
    required this.time,
    required this.impact,
  });
  final bool compact;
  final Widget severity, title, providers, trend, time, impact;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 96, child: Align(alignment: Alignment.centerLeft, child: severity)),
        Expanded(child: title),
        if (!compact) ...[
          const SizedBox(width: 16),
          SizedBox(width: 72, child: Align(alignment: Alignment.centerLeft, child: providers)),
          const SizedBox(width: 16),
          SizedBox(width: 110, child: trend),
          const SizedBox(width: 16),
          SizedBox(width: 72, child: Align(alignment: Alignment.centerLeft, child: time)),
        ],
        const SizedBox(width: 16),
        SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: impact)),
      ]);
}

class _TitleCell extends StatelessWidget {
  const _TitleCell(this.title, this.summary, {this.muted = false});
  final String title;
  final String summary;
  final bool muted;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: muted ? AppColors.mutedForeground : AppColors.foreground)),
        const SizedBox(height: 2),
        Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
      ]);
}

class _ImpactCell extends StatelessWidget {
  const _ImpactCell(this.value, this.label, {this.muted = false});
  final String value;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: muted ? AppColors.mutedForeground : AppColors.foreground)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(fontSize: 11)),
      ]);
}

// -------------------------------------------------------------- savings ----

class SavingsPage extends StatelessWidget {
  const SavingsPage({super.key, required this.onOpen});
  final OpenTopic onOpen;

  @override
  Widget build(BuildContext context) {
    const t = totalSuggestion;
    final all = [...suggestions, ...moreSuggestions];
    return _PageScaffold(
      title: 'Savings',
      subtitle: '${t.savings} per month across ${all.length} opportunities · ${t.percent} of the forecast',
      trailing: ShadButton(
        label: 'Review with Stratus',
        icon: Icons.auto_awesome_outlined,
        small: true,
        onPressed: () => onOpen('Reduce cloud spend by ${t.percent}', t.id),
      ),
      children: [
        _BudgetBar(forecast: t.forecast, budget: t.budget, saving: t.saving),
        const SizedBox(height: 28),
        _Table(
          header: Row(children: [
            const SizedBox(width: 28),
            Expanded(child: _head('Opportunity')),
            const SizedBox(width: 16),
            SizedBox(width: 110, child: _head('Risk')),
            const SizedBox(width: 16),
            SizedBox(width: 90, child: _head('Per month', align: TextAlign.right)),
          ]),
          rows: [
            for (final s in all)
              _Row(
                onTap: () => onOpen(s.title, s.id),
                child: Row(children: [
                  SizedBox(width: 28, child: ProviderLogo(provider: s.provider, size: 16)),
                  Expanded(child: _TitleCell(s.title, s.summary)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 110,
                    child: Text(s.tag,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: s.tag == 'Fixes incident' ? AppColors.chartPalette[0] : AppColors.mutedForeground)),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 90,
                    child: Text(s.savings,
                        textAlign: TextAlign.right,
                        style: AppText.mono(size: 13, color: AppColors.success, weight: FontWeight.w600)),
                  ),
                ]),
              ),
          ],
        ),
      ],
    );
  }
}

/// Forecast vs. budget, with the share that the savings would remove.
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.forecast, required this.budget, required this.saving});
  final double forecast;
  final double budget;
  final double saving;

  @override
  Widget build(BuildContext context) {
    final after = forecast - saving;
    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppText.small),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: color ?? AppColors.foreground)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          stat('November forecast', '€${forecast}k'),
          stat('Budget', '€${budget}k'),
          stat('After savings', '€${after.toStringAsFixed(1)}k', color: AppColors.success),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          return SizedBox(
            height: 22,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 8,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: after / forecast),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Row(children: [
                    Container(
                      width: w * v,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(3)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              Positioned(
                left: w * budget / forecast - 1,
                top: 2,
                child: Container(width: 2, height: 18, color: AppColors.destructive),
              ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        Row(children: [
          const Dot(color: AppColors.primary, size: 7),
          const SizedBox(width: 6),
          const Text('Spend after savings', style: AppText.small),
          const SizedBox(width: 16),
          const Dot(color: AppColors.success, size: 7),
          const SizedBox(width: 6),
          const Text('Savings', style: AppText.small),
          const SizedBox(width: 16),
          Container(width: 2, height: 10, color: AppColors.destructive),
          const SizedBox(width: 6),
          const Text('Budget', style: AppText.small),
        ]),
      ]),
    );
  }
}
