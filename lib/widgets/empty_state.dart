import 'package:flutter/material.dart';

import '../theme.dart';
import 'sidebar.dart';
import 'ui/primitives.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onPick});
  final ValueChanged<String> onPick;

  static const _suggestions = [
    (Icons.speed_rounded, 'Why is my checkout slow?', 'Trace latency across every provider'),
    (Icons.savings_outlined, 'Where can I cut cloud costs?', 'Find idle and oversized resources'),
    (Icons.history_rounded, 'What changed in the last 24h?', 'Deploys, config and region moves'),
    (Icons.hub_outlined, 'Give me an overview of production', 'Health of all services at a glance'),
  ];

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const AppLogo(size: 44),
              const SizedBox(height: 20),
              const Text('Ask your infrastructure anything',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.8)),
              const SizedBox(height: 8),
              const Text(
                'One agent across AWS, Google Cloud, Azure and codesphere. It investigates, explains and fixes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: AppColors.mutedForeground, height: 1.5),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth > 520 ? 2 : 1;
                final w = (box.maxWidth - 12 * (cols - 1)) / cols;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final s in _suggestions)
                    SizedBox(
                      width: w,
                      child: _SuggestionCard(
                          icon: s.$1, title: s.$2, subtitle: s.$3, onTap: () => onPick(s.$2)),
                    ),
                ]);
              }),
            ]),
          ),
        ),
      );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard(
      {required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HoverBuilder(
        onTap: onTap,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hovered ? AppColors.subtle : AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: hovered ? AppColors.borderStrong : AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppColors.muted, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, size: 16, color: AppColors.foreground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.small),
              ]),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: hovered ? 1 : 0,
              child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.mutedForeground),
            ),
          ]),
        ),
      );
}
