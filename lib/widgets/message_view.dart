import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/ui_block.dart';
import '../theme.dart';
import '../util/format.dart';
import 'blocks/block_renderer.dart';
import 'ui/cloud_avatar.dart';
import 'ui/common.dart';
import 'ui/primitives.dart';

class MessageView extends StatelessWidget {
  const MessageView(
      {super.key, required this.message, required this.onAction, required this.onAsk});
  final ChatMessage message;
  final void Function(ActionsBlock, ActionItem) onAction;
  final void Function(FollowUpsBlock, String) onAsk;

  @override
  Widget build(BuildContext context) =>
      message.role == Role.user ? _user() : _assistant();

  Widget _user() {
    final text = message.parts.whereType<TextPart>().map((p) => p.text).join();
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: message.isAction ? AppColors.background : AppColors.muted,
            border: message.isAction ? Border.all(color: AppColors.border) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: message.isAction
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded,
                      size: 15, color: AppColors.mutedForeground),
                  const SizedBox(width: 6),
                  Flexible(child: Text(text, style: AppText.body.copyWith(fontSize: 13.5))),
                ])
              : Text(text, style: AppText.body),
        ),
      ),
    );
  }

  Widget _assistant() {
    final children = <Widget>[];
    if (message.steps.isNotEmpty) children.add(StepsView(message: message));
    for (var i = 0; i < message.parts.length; i++) {
      final part = message.parts[i];
      final w = switch (part) {
        TextPart p => RichMarkdownText(p.text),
        BlockPart p => BlockRenderer(block: p.block, onAction: onAction, onAsk: onAsk),
      };
      children.add(AnimatedAppear(key: ValueKey('${message.id}-$i'), child: w));
    }
    if (!message.done && message.steps.isEmpty && message.parts.isEmpty) {
      children.add(Row(children: const [
        Spinner(size: 12),
        SizedBox(width: 8),
        Text('Thinking…', style: AppText.muted),
      ]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CloudAvatar(thinking: !message.done),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ]),
      ),
    ]);
  }
}

class AgentAvatar extends StatelessWidget {
  const AgentAvatar({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(size * 0.28)),
        child: Icon(Icons.auto_awesome, size: size * 0.52, color: AppColors.primaryForeground),
      );
}

/// Collapsible list of the agent's background work.
class StepsView extends StatefulWidget {
  const StepsView({super.key, required this.message});
  final ChatMessage message;

  @override
  State<StepsView> createState() => _StepsViewState();
}

class _StepsViewState extends State<StepsView> {
  bool? _expanded;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final steps = m.steps;
    final finished = steps.where((s) => s.status == StepStatus.done).length;
    final running = !m.done;
    final expanded = _expanded ?? running;
    final total = m.finishedAt?.difference(m.createdAt);
    final title = running
        ? 'Investigating…'
        : 'Investigated ${steps.length} step${steps.length == 1 ? '' : 's'}';
    final meta = running ? '$finished/${steps.length}' : (total == null ? '' : formatDuration(total));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HoverBuilder(
          onTap: () => setState(() => _expanded = !expanded),
          builder: (context, hovered) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              running
                  ? const Spinner(size: 14)
                  : const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
              const SizedBox(width: 10),
              Text(title, style: AppText.title.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Text(meta, style: AppText.mono(size: 11.5)),
              const Spacer(),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: hovered ? AppColors.foreground : AppColors.mutedForeground),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(children: [
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Column(children: [for (final s in steps) _StepRow(step: s)]),
                  ),
                ])
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final icon = switch (step.status) {
      StepStatus.running => const Spinner(size: 12),
      StepStatus.done => const Icon(Icons.check_rounded, size: 15, color: AppColors.success),
      StepStatus.failed => const Icon(Icons.close_rounded, size: 15, color: AppColors.destructive),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 16, child: Center(child: icon)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  color: step.status == StepStatus.running
                      ? AppColors.foreground
                      : AppColors.mutedForeground)),
        ),
        if (step.source != null) ...[
          const SizedBox(width: 8),
          ProviderBadge(provider: step.source!),
        ],
        const Spacer(),
        if (step.detail != null) Text(step.detail!, style: AppText.mono(size: 11.5)),
        SizedBox(
          width: 48,
          child: Text(step.took == null ? '' : formatDuration(step.took!),
              textAlign: TextAlign.right,
              style: AppText.mono(size: 11.5, color: AppColors.borderStrong)),
        ),
      ]),
    );
  }
}
