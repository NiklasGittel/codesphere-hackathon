import 'package:flutter/material.dart';

import '../../theme.dart';

/// Hover + tap helper used by all interactive primitives.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder, this.onTap});
  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: widget.builder(context, _hovered),
        ),
      );
}

class ShadCard extends StatelessWidget {
  const ShadCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color ?? AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor ?? AppColors.border),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: child,
      );
}

class CardHeader extends StatelessWidget {
  const CardHeader(
      {super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.muted),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      );
}

enum ButtonVariant { primary, secondary, outline, ghost, destructive }

ButtonVariant parseVariant(String v) => ButtonVariant.values
    .firstWhere((b) => b.name == v, orElse: () => ButtonVariant.outline);

class ShadButton extends StatelessWidget {
  const ShadButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.small = false,
    this.tooltip,
  });
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool small;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final h = small ? 32.0 : 36.0;
    final button = HoverBuilder(
      onTap: onPressed,
      builder: (context, hovered) {
        final hover = hovered && enabled;
        late Color bg, fg;
        Color? border;
        switch (variant) {
          case ButtonVariant.primary:
            bg = hover ? AppColors.primaryHover : AppColors.primary;
            fg = AppColors.primaryForeground;
          case ButtonVariant.secondary:
            bg = hover ? AppColors.border : AppColors.muted;
            fg = AppColors.foreground;
          case ButtonVariant.outline:
            bg = hover ? AppColors.muted : AppColors.background;
            fg = AppColors.foreground;
            border = AppColors.border;
          case ButtonVariant.ghost:
            bg = hover ? AppColors.muted : Colors.transparent;
            fg = AppColors.foreground;
          case ButtonVariant.destructive:
            bg = hover ? const Color(0xFFB91C1C) : AppColors.destructive;
            fg = Colors.white;
        }
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: h,
            width: label == null ? h : null,
            padding: EdgeInsets.symmetric(
                horizontal: label == null ? 0 : (small ? 12 : 16)),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: border == null ? null : Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Icon(icon, size: 16, color: fg),
                if (icon != null && label != null) const SizedBox(width: 8),
                if (label != null)
                  Text(label!,
                      style: TextStyle(
                          fontSize: small ? 13 : 13.5,
                          fontWeight: FontWeight.w500,
                          color: fg)),
              ],
            ),
          ),
        );
      },
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class ShadBadge extends StatelessWidget {
  const ShadBadge({super.key, required this.label, this.color, this.leading});
  final String label;

  /// null = neutral outline badge; otherwise tinted.
  final Color? color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c == null ? AppColors.background : c.withAlpha(22),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c == null ? AppColors.border : c.withAlpha(60)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: c ?? AppColors.foreground)),
      ]),
    );
  }
}

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 14, this.color = AppColors.foreground});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
      );
}

class Dot extends StatelessWidget {
  const Dot({super.key, required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
