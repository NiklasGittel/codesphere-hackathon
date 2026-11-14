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
    final critical = incidents.where((i) => i.severity == Severity.critical).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 860;
            final incidentCol = _IncidentsSection(onOpen: onOpen);
            final savingsCol = _SavingsSection(onOpen: onOpen);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.7)),
              const SizedBox(height: 4),
              Text.rich(TextSpan(style: const TextStyle(fontSize: 14, color: AppColors.mutedForeground), children: [
                TextSpan(text: '$date · '),
                TextSpan(
                    text: '$critical critical incident${critical == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.destructive, fontWeight: FontWeight.w500)),
                const TextSpan(text: ' and '),
                const TextSpan(
                    text: '€11.4k/month in savings',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w500)),
                const TextSpan(text: ' need your attention.'),
              ])),
              const SizedBox(height: 22),
              _ProviderStrip(wide: wide),
              const SizedBox(height: 28),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: incidentCol),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: savingsCol),
                ])
              else ...[
                incidentCol,
                const SizedBox(height: 28),
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

// ------------------------------------------------------- provider strip ----

class _ProviderStrip extends StatelessWidget {
  const _ProviderStrip({required this.wide});
  final bool wide;

  static const _items = [
    ('aws', 'Healthy', '12 services', Severity.success),
    ('gcp', 'Degraded', '1 critical incident', Severity.critical),
    ('azure', '2 warnings', '9 services', Severity.warning),
    ('codesphere', 'Healthy', '5 workspaces', Severity.success),
  ];

  @override
  Widget build(BuildContext context) {
    final tiles = [for (final i in _items) _ProviderTile(id: i.$1, status: i.$2, detail: i.$3, severity: i.$4)];
    if (wide) {
      return Row(children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: tiles[i]),
        ],
      ]);
    }
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.id, required this.status, required this.detail, required this.severity});
  final String id;
  final String status;
  final String detail;
  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final p = providerInfo(id);
    final s = severityStyle(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: ProviderLogo(provider: id, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Row(children: [
              Dot(color: s.fg, size: 6),
              const SizedBox(width: 6),
              Flexible(
                child: Text('$status · $detail',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small.copyWith(fontSize: 11.5)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------ sections ----

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.badge, this.badgeColor});
  final String title;
  final String badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
          const SizedBox(width: 8),
          ShadBadge(label: badge, color: badgeColor),
          const Spacer(),
          const Text('View all', style: AppText.muted),
        ]),
      );
}

class _IncidentsSection extends StatelessWidget {
  const _IncidentsSection({required this.onOpen});
  final OpenTopic onOpen;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionHeader(title: 'Incidents', badge: '${incidents.length} open', badgeColor: AppColors.destructive),
        for (var i = 0; i < incidents.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _IncidentCard(incident: incidents[i], onTap: () => onOpen(incidents[i].title, incidents[i].id)),
        ],
      ]);
}

class _SavingsSection extends StatelessWidget {
  const _SavingsSection({required this.onOpen});
  final OpenTopic onOpen;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(title: 'Savings', badge: '€11.4k / month', badgeColor: AppColors.success),
        _SavingsHero(onTap: () => onOpen('Reduce cloud spend by ${totalSuggestion.percent}', totalSuggestion.id)),
        for (final s in suggestions) ...[
          const SizedBox(height: 10),
          _SuggestionCard(suggestion: s, onTap: () => onOpen(s.title, s.id)),
        ],
      ]);
}

// --------------------------------------------------------------- cards ----

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onTap});
  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = severityStyle(incident.severity);
    final critical = incident.severity == Severity.critical;
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: hovered
                ? (critical ? s.fg.withAlpha(130) : AppColors.borderStrong)
                : (critical ? s.border : AppColors.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(hovered ? 0x14000000 : 0x08000000),
              blurRadius: hovered ? 18 : 3,
              offset: Offset(0, hovered ? 6 : 1),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ShadBadge(
              label: critical ? 'Critical' : 'Warning',
              color: s.fg,
              leading: Dot(color: s.fg, size: 6),
            ),
            const SizedBox(width: 10),
            Text('Ongoing · ${incident.since}', style: AppText.small),
            const Spacer(),
            for (final p in incident.providers)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: providerInfo(p).name,
                  child: ProviderLogo(provider: p, size: 16),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(incident.title,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(incident.summary, style: AppText.muted.copyWith(fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(incident.impact,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: critical ? s.fg : AppColors.foreground)),
              Text(incident.impactLabel, style: AppText.small.copyWith(fontSize: 11.5)),
            ]),
          ]),
          const SizedBox(height: 12),
          Sparkline(values: incident.trend, color: s.fg, height: critical ? 44 : 32),
          const SizedBox(height: 10),
          Row(children: [
            Text('Investigate',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: hovered ? AppColors.foreground : AppColors.mutedForeground)),
            AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.only(left: hovered ? 8 : 4),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 15, color: hovered ? AppColors.foreground : AppColors.mutedForeground),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SavingsHero extends StatelessWidget {
  const _SavingsHero({required this.onTap});
  final VoidCallback onTap;

  static const _green = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    const t = totalSuggestion;
    final budgetFrac = t.budget / t.forecast;
    final keepFrac = (t.forecast - t.saving) / t.forecast;
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: hovered ? AppColors.primaryHover : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Color(hovered ? 0x26000000 : 0x14000000),
              blurRadius: hovered ? 20 : 8,
              offset: Offset(0, hovered ? 8 : 2),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reduce cloud spend by',
              style: TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF))),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(t.percent,
                style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1.2, color: Colors.white, height: 1.1)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text('${t.savings} / month',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _green)),
            ),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            return SizedBox(
              height: 26,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 8,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: keepFrac),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Row(children: [
                      Container(
                        width: w * v,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xE6FFFFFF),
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(5)),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(5)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                Positioned(
                  left: w * budgetFrac - 1,
                  top: 3,
                  child: Container(width: 2, height: 20, color: const Color(0xFFF87171)),
                ),
              ]),
            );
          }),
          const SizedBox(height: 8),
          Row(children: [
            Text('Forecast €${t.forecast}k',
                style: const TextStyle(fontSize: 11.5, color: Color(0x99FFFFFF))),
            const SizedBox(width: 10),
            Text('Budget €${t.budget}k',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFFF87171))),
            const Spacer(),
            Text('After savings €${(t.forecast - t.saving).toStringAsFixed(1)}k',
                style: const TextStyle(fontSize: 11.5, color: _green)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Review 23 opportunities',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
            AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.only(left: hovered ? 8 : 4),
              child: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onTap});
  final Suggestion suggestion;
  final VoidCallback onTap;

  IconData get _icon => switch (suggestion.id) {
        'suggest_gpu' => Icons.memory_rounded,
        'rightsize' => Icons.compress_rounded,
        'suggest_egress' => Icons.swap_horiz_rounded,
        _ => Icons.savings_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final fixes = suggestion.tag == 'Fixes incident';
    return HoverBuilder(
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hovered ? AppColors.subtle : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: hovered ? AppColors.borderStrong : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(_icon, size: 17, color: AppColors.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(suggestion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(suggestion.summary,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ProviderBadge(provider: suggestion.provider),
                ShadBadge(
                    label: suggestion.tag,
                    color: fixes ? AppColors.chartPalette[0] : AppColors.success),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(suggestion.savings,
                style: AppText.mono(size: 15, color: AppColors.success, weight: FontWeight.w600)),
            const Text('/ month', style: AppText.small),
          ]),
        ]),
      ),
    );
  }
}
