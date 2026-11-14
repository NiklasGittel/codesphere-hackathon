import 'package:flutter/material.dart';

import '../theme.dart';
import 'ui/common.dart';
import 'ui/primitives.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 26});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(size * 0.27)),
        child: Icon(Icons.cloud_outlined, size: size * 0.56, color: AppColors.primaryForeground),
      );
}

/// Navigation ids handled by HomeScreen.
class NavIds {
  static const overview = 'overview';
  static const incidents = 'incidents';
  static const services = 'services';
  static const changes = 'changes';
  static const savings = 'savings';
  static const costs = 'costs';
  static const settings = 'settings';
}

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.selected,
    required this.onNavigate,
    required this.onNewChat,
  });

  final String? selected;
  final ValueChanged<String> onNavigate;
  final VoidCallback onNewChat;

  static const recent = [
    ('recent_checkout', 'Checkout latency spike', 'Ongoing'),
    ('recent_costs', 'November cost review', '2 d ago'),
    ('recent_changes', 'Production changes', '3 d ago'),
  ];

  static const _providers = [
    ('aws', true),
    ('gcp', false),
    ('azure', true),
    ('codesphere', true),
  ];

  Widget _item(String id, IconData icon, String label, {Widget? trailing}) => _NavItem(
        icon: icon,
        label: label,
        active: selected == id,
        trailing: trailing,
        onTap: () => onNavigate(id),
      );

  @override
  Widget build(BuildContext context) => Container(
        width: 264,
        color: AppColors.subtle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 0),
            child: Row(children: [
              const AppLogo(),
              const SizedBox(width: 10),
              const Text('Stratus',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              const Spacer(),
              ShadButton(
                icon: Icons.add_comment_outlined,
                variant: ButtonVariant.ghost,
                small: true,
                tooltip: 'New investigation',
                onPressed: onNewChat,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: _SearchField(onTap: onNewChat),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _SectionLabel('Monitor'),
                _item(NavIds.overview, Icons.space_dashboard_outlined, 'Overview'),
                _item(NavIds.incidents, Icons.error_outline_rounded, 'Incidents',
                    trailing: const _CountBadge(label: '3', color: AppColors.destructive)),
                _item(NavIds.services, Icons.hub_outlined, 'Service map',
                    trailing: const _CountBadge(label: '38')),
                _item(NavIds.changes, Icons.history_rounded, 'Changes',
                    trailing: const _CountBadge(label: '3')),
                const SizedBox(height: 16),
                const _SectionLabel('Optimize'),
                _item(NavIds.savings, Icons.savings_outlined, 'Savings',
                    trailing: const _CountBadge(label: '€11.4k', color: AppColors.success)),
                _item(NavIds.costs, Icons.bar_chart_rounded, 'Cost explorer'),
                const SizedBox(height: 16),
                const _SectionLabel('Recent investigations'),
                for (final r in recent)
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: r.$2,
                    dense: true,
                    active: selected == r.$1,
                    trailing: Text(r.$3,
                        style: AppText.small.copyWith(
                            fontSize: 11,
                            color: r.$3 == 'Ongoing' ? AppColors.destructive : AppColors.mutedForeground)),
                    onTap: () => onNavigate(r.$1),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: _ProvidersCard(providers: _providers),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: _item(NavIds.settings, Icons.settings_outlined, 'Settings'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Divider(height: 1, color: AppColors.border),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 14, 14),
            child: _Workspace(),
          ),
        ]),
      );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: hovered ? AppColors.borderStrong : AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 15, color: AppColors.mutedForeground),
            const SizedBox(width: 8),
            const Expanded(child: Text('Ask or search…', style: AppText.muted)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('⌘K', style: AppText.mono(size: 10.5)),
            ),
          ]),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Text(text, style: AppText.label),
      );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color == null ? AppColors.muted : color!.withAlpha(24),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color ?? AppColors.mutedForeground)),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.dense = false,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool dense;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: dense ? 32 : 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: active ? AppColors.border.withAlpha(200) : (hovered ? AppColors.muted : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Icon(icon,
                size: dense ? 14 : 16,
                color: active ? AppColors.foreground : AppColors.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: dense ? 12.5 : 13,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      color: dense && !active ? AppColors.mutedForeground : AppColors.foreground)),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ]),
        ),
      );
}

class _ProvidersCard extends StatelessWidget {
  const _ProvidersCard({required this.providers});
  final List<(String, bool)> providers;

  @override
  Widget build(BuildContext context) {
    final degraded = providers.where((p) => !p.$2).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Providers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Dot(color: degraded == 0 ? AppColors.success : AppColors.warning, size: 6),
          const SizedBox(width: 5),
          Text(degraded == 0 ? 'All healthy' : '$degraded degraded',
              style: AppText.small.copyWith(fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < providers.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Row(children: [
              for (var j = i; j < i + 2 && j < providers.length; j++)
                Expanded(child: _ProviderChip(id: providers[j].$1, healthy: providers[j].$2)),
            ]),
          ),
      ]),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.id, required this.healthy});
  final String id;
  final bool healthy;

  @override
  Widget build(BuildContext context) {
    final p = providerInfo(id);
    return Tooltip(
      message: '${p.name} · ${healthy ? 'healthy' : 'degraded'}',
      child: Row(children: [
        Dot(color: p.color, size: 8),
        const SizedBox(width: 6),
        Flexible(
          child: Text(p.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 4),
        Icon(healthy ? Icons.check_rounded : Icons.warning_amber_rounded,
            size: 12, color: healthy ? AppColors.success : AppColors.warning),
      ]),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace();

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
          child: const Text('A',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryForeground)),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Acme Shop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text('Production workspace', style: AppText.small),
          ]),
        ),
        const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.mutedForeground),
      ]);
}
