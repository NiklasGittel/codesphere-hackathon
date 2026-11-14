import 'package:flutter/material.dart';

import '../../models/ui_block.dart';
import '../../theme.dart';
import 'primitives.dart';

class ProviderInfo {
  const ProviderInfo(this.name, this.color);
  final String name;
  final Color color;
}

ProviderInfo providerInfo(String? id) => switch (id?.toLowerCase()) {
      'aws' => const ProviderInfo('AWS', Color(0xFFFF9900)),
      'gcp' => const ProviderInfo('Google Cloud', Color(0xFF4285F4)),
      'azure' => const ProviderInfo('Azure', Color(0xFF0078D4)),
      'codesphere' => const ProviderInfo('codesphere', Color(0xFF7C3AED)),
      _ => ProviderInfo(id ?? 'Unknown', AppColors.mutedForeground),
    };

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({super.key, required this.provider});
  final String provider;

  @override
  Widget build(BuildContext context) {
    final p = providerInfo(provider);
    return ShadBadge(label: p.name, leading: Dot(color: p.color, size: 6));
  }
}

class SeverityStyle {
  const SeverityStyle(this.fg, this.bg, this.border, this.icon);
  final Color fg;
  final Color bg;
  final Color border;
  final IconData icon;
}

SeverityStyle severityStyle(Severity s) => switch (s) {
      Severity.critical => const SeverityStyle(AppColors.destructive,
          Color(0xFFFEF2F2), Color(0xFFFECACA), Icons.error_outline_rounded),
      Severity.warning => const SeverityStyle(AppColors.warning,
          Color(0xFFFFFBEB), Color(0xFFFDE68A), Icons.warning_amber_rounded),
      Severity.success => const SeverityStyle(AppColors.success,
          Color(0xFFF0FDF4), Color(0xFFBBF7D0), Icons.check_circle_outline_rounded),
      Severity.info => const SeverityStyle(AppColors.foreground,
          AppColors.background, AppColors.border, Icons.info_outline_rounded),
    };

IconData actionIcon(String? name) => switch (name) {
      'rollback' => Icons.history_rounded,
      'bolt' => Icons.bolt_rounded,
      'ticket' => Icons.confirmation_number_outlined,
      'resize' => Icons.compress_rounded,
      'stop' => Icons.stop_circle_outlined,
      'export' => Icons.description_outlined,
      'check' => Icons.check_rounded,
      'close' => Icons.close_rounded,
      'play' => Icons.play_arrow_rounded,
      'savings' => Icons.savings_outlined,
      _ => Icons.arrow_forward_rounded,
    };

/// Minimal inline markdown: **bold** and `code`.
class RichMarkdownText extends StatelessWidget {
  const RichMarkdownText(this.text, {super.key, this.style = AppText.body});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w600)));
      } else {
        spans.add(TextSpan(
            text: m.group(2),
            style: AppText.mono(
                    size: (style.fontSize ?? 14) - 1.5,
                    color: AppColors.foreground)
                .copyWith(backgroundColor: AppColors.muted)));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// Fade + slide in, played once when the widget is first built.
class AnimatedAppear extends StatelessWidget {
  const AnimatedAppear({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 10 * (1 - t)), child: child),
        ),
        child: child,
      );
}
