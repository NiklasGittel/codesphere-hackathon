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

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.onNewChat, this.overviewActive = false});
  final VoidCallback onNewChat;
  final bool overviewActive;

  static const _recent = [
    'Checkout latency spike',
    'November cost review',
    'EU data residency audit',
    'Black Friday capacity plan',
  ];

  static const _providers = [
    ('aws', 'eu-central-1 +2'),
    ('gcp', 'us-east1 +1'),
    ('azure', 'westeurope'),
    ('codesphere', 'fra-1'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: 264,
        color: AppColors.subtle,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              const AppLogo(),
              const SizedBox(width: 10),
              const Text('Stratus',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              const Spacer(),
              const ShadBadge(label: 'beta'),
            ]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              label: 'New investigation',
              icon: Icons.add_rounded,
              variant: ButtonVariant.outline,
              onPressed: onNewChat,
            ),
          ),
          const SizedBox(height: 12),
          _NavItem(
            icon: Icons.space_dashboard_outlined,
            label: 'Overview',
            active: overviewActive,
            onTap: onNewChat,
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Recent'),
          const SizedBox(height: 4),
          for (final r in _recent) _NavItem(icon: Icons.chat_bubble_outline_rounded, label: r),
          const Spacer(),
          const _SectionLabel('Connected providers'),
          const SizedBox(height: 6),
          for (final p in _providers) _ProviderRow(id: p.$1, regions: p.$2),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                child: const Text('A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Acme Shop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text('Production workspace', style: AppText.small),
                ]),
              ),
              const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.mutedForeground),
            ]),
          ),
        ]),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text, style: AppText.label),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.active = false, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap ?? () {},
        builder: (context, hovered) => Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: active
                ? AppColors.border
                : (hovered ? AppColors.muted : Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            Icon(icon, size: 15, color: active ? AppColors.foreground : AppColors.mutedForeground),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      color: AppColors.foreground)),
            ),
          ]),
        ),
      );
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.id, required this.regions});
  final String id;
  final String regions;

  @override
  Widget build(BuildContext context) {
    final p = providerInfo(id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(children: [
        Dot(color: p.color, size: 8),
        const SizedBox(width: 10),
        Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
        Text(regions, style: AppText.mono(size: 10.5)),
        const SizedBox(width: 8),
        const Dot(color: AppColors.success, size: 6),
      ]),
    );
  }
}
