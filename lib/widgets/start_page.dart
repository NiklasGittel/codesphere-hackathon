import 'package:flutter/material.dart';

import '../data/start_data.dart';
import '../models/ui_block.dart';
import '../theme.dart';
import 'ui/common.dart';
import 'ui/primitives.dart';
import 'ui/sparkline.dart';

typedef OpenTopic = void Function(String title, String actionId);

/// Overview of what needs attention: incidents and savings opportunities.
class StartPage extends StatelessWidget {
  const StartPage({super.key, required this.onOpen});
  final OpenTopic onOpen;

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good morning' : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    final date = '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 860;
            final incidentsCol = _IncidentsSection(onOpen: onOpen);
            final savingsCol = _SavingsSection(onOpen: onOpen);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
              const SizedBox(height: 4),
              Text('$date · Monitoring 38 services across 4 providers',
                  style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
              const SizedBox(height: 24),
              _ProviderBar(wide: wide),
              const SizedBox(height: 36),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: incidentsCol),
                  const SizedBox(width: 32),
                  Expanded(flex: 2, child: savingsCol),
                ])
              else ...[
                incidentsCol,
                const SizedBox(height: 32),
                savingsCol,
              ],
              const SizedBox(height: 16),
            ]);
          }),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ providers ----

class _ProviderBar extends StatelessWidget {
  const _ProviderBar({required this.wide});
  final bool wide;

  static const _items = [
    ('aws', 'Healthy', Severity.success),
    ('gcp', 'Degraded', Severity.critical),
    ('azure', '2 warnings', Severity.warning),
    ('codesphere', 'Healthy', Severity.success),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [for (final i in _items) _ProviderItem(id: i.$1, status: i.$2, severity: i.$3)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: wide
          ? Row(children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Container(width: 1, height: 28, color: AppColors.border),
                Expanded(child: items[i]),
              ],
            ])
          : Wrap(runSpacing: 12, children: [
              for (final item in items) FractionallySizedBox(widthFactor: 0.5, child: item),
            ]),
    );
  }
}

class _ProviderItem extends StatelessWidget {
  const _ProviderItem({required this.id, required this.status, required this.severity});
  final String id;
  final String status;
  final Severity severity;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          ProviderLogo(provider: id, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(providerInfo(id).name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Row(children: [
                Dot(color: severityStyle(severity).fg, size: 6),
                const SizedBox(width: 6),
                Text(status, style: AppText.small.copyWith(fontSize: 11.5)),
              ]),
            ]),
          ),
        ]),
      );
}

// ------------------------------------------------------------- sections ----

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.meta);
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(meta, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        ]),
      );
}

/// Bordered list container with dividers between rows.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.border),
            children[i],
          ],
        ]),
      );
}

class _IncidentsSection extends StatelessWidget {
  const _IncidentsSection({required this.onOpen});
  final OpenTopic onOpen;

  @override
  Widget build(BuildContext context) {
    final critical = incidents.where((i) => i.severity == Severity.critical).toList();
    final others = incidents.where((i) => i.severity != Severity.critical).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle('Incidents', '${incidents.length} open'),
      for (final i in critical) ...[
        _CriticalIncident(incident: i, onTap: () => onOpen(i.title, i.id)),
        const SizedBox(height: 12),
      ],
      if (others.isNotEmpty)
        _ListCard(children: [
          for (final i in others) _IncidentRow(incident: i, onTap: () => onOpen(i.title, i.id)),
        ]),
    ]);
  }
}

class _SavingsSection extends StatelessWidget {
  const _SavingsSection({required this.onOpen});
  final OpenTopic onOpen;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SectionTitle('Savings', '${suggestions.length + 1} opportunities'),
        _ListCard(children: [
          _SavingsTotal(onTap: () => onOpen('Reduce cloud spend by ${totalSuggestion.percent}', totalSuggestion.id)),
          for (final s in suggestions) _SuggestionRow(suggestion: s, onTap: () => onOpen(s.title, s.id)),
        ]),
      ]);
}

// --------------------------------------------------------------- items ----

class _CriticalIncident extends StatelessWidget {
  const _CriticalIncident({required this.incident, required this.onTap});
  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final red = severityStyle(incident.severity).fg;
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: hovered ? AppColors.borderStrong : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Color(hovered ? 0x10000000 : 0x00000000),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Dot(color: red, size: 7),
            const SizedBox(width: 8),
            Text('Critical · ongoing ${incident.since}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: red)),
            const Spacer(),
            for (final p in incident.providers)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(message: providerInfo(p).name, child: ProviderLogo(provider: p, size: 16)),
              ),
          ]),
          const SizedBox(height: 14),
          Text(incident.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text(incident.summary, style: AppText.muted.copyWith(fontSize: 13.5)),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Sparkline(values: incident.trend, color: red, height: 48)),
            const SizedBox(width: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(incident.impact,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              Text(incident.impactLabel, style: AppText.small.copyWith(fontSize: 11.5)),
            ]),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: hovered ? 26 : 0,
              alignment: Alignment.centerRight,
              child: hovered
                  ? const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.foreground)
                  : null,
            ),
          ]),
        ]),
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident, required this.onTap});
  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: hovered ? AppColors.subtle : AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Dot(color: severityStyle(incident.severity).fg, size: 7),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(incident.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(incident.summary,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
              ]),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(incident.impact, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text(incident.impactLabel, style: AppText.small.copyWith(fontSize: 11)),
            ]),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: hovered ? AppColors.foreground : AppColors.borderStrong),
          ]),
        ),
      );
}

class _SavingsTotal extends StatelessWidget {
  const _SavingsTotal({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const t = totalSuggestion;
    final frac = t.saving / t.forecast;
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: hovered ? AppColors.subtle : AppColors.background,
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(t.savings,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.6)),
                const SizedBox(width: 6),
                const Text('/ month', style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              ]),
              const SizedBox(height: 2),
              Text('${t.percent} of the €${t.forecast}k forecast', style: AppText.small),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) => Stack(children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(3)),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Container(
                      width: box.maxWidth * v,
                      height: 6,
                      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: hovered ? AppColors.foreground : AppColors.borderStrong),
        ]),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.suggestion, required this.onTap});
  final Suggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: hovered ? AppColors.subtle : AppColors.background,
          padding: const EdgeInsets.fromLTRB(20, 13, 16, 13),
          child: Row(children: [
            ProviderLogo(provider: suggestion.provider, size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(suggestion.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(suggestion.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
              ]),
            ),
            const SizedBox(width: 12),
            Text(suggestion.savings,
                style: AppText.mono(size: 13, color: AppColors.success, weight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: hovered ? AppColors.foreground : AppColors.borderStrong),
          ]),
        ),
      );
}
