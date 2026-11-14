import 'package:flutter/material.dart';

import '../../models/ui_block.dart';
import '../../theme.dart';
import '../ui/common.dart';
import '../ui/primitives.dart';

// ------------------------------------------------------------- topology ----

class TopologyCard extends StatelessWidget {
  const TopologyCard({super.key, required this.block});
  final TopologyBlock block;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < block.nodes.length; i++) {
      if (i > 0) {
        final edge = block.edgeBetween(block.nodes[i - 1].id, block.nodes[i].id);
        children.add(_Edge(edge: edge));
      }
      children.add(_Node(node: block.nodes[i]));
    }
    return ShadCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardHeader(title: block.title, subtitle: block.subtitle),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: children),
        ),
      ]),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.node});
  final TopoNode node;

  @override
  Widget build(BuildContext context) {
    final p = providerInfo(node.provider);
    final s = severityStyle(node.status);
    final flagged = node.status != Severity.info;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: flagged ? s.bg : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: flagged ? s.border : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Dot(color: p.color, size: 7),
          const SizedBox(width: 6),
          Expanded(
            child: Text(p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(fontSize: 11.5)),
          ),
          if (flagged) Icon(s.icon, size: 14, color: s.fg),
        ]),
        const SizedBox(height: 8),
        Text(node.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(size: 12.5, color: AppColors.foreground, weight: FontWeight.w600)),
        if (node.region != null) ...[
          const SizedBox(height: 2),
          Text(node.region!, style: AppText.mono(size: 11)),
        ],
      ]),
    );
  }
}

class _Edge extends StatelessWidget {
  const _Edge({required this.edge});
  final TopoEdge? edge;

  @override
  Widget build(BuildContext context) {
    final status = edge?.status ?? Severity.info;
    final c = status == Severity.info ? AppColors.borderStrong : severityStyle(status).fg;
    final labelColor = status == Severity.info ? AppColors.mutedForeground : c;
    return SizedBox(
      width: 92,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(edge?.label ?? '',
              style: AppText.mono(
                  size: 11,
                  color: labelColor,
                  weight: status == Severity.critical ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Container(height: status == Severity.critical ? 2 : 1.5, color: c)),
            Icon(Icons.play_arrow_rounded, size: 12, color: c),
          ]),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- table ----

class TableCard extends StatelessWidget {
  const TableCard({super.key, required this.block});
  final TableBlock block;

  bool _isNumeric(String s) => RegExp(r'^[~€$\-+]?[\d.,]').hasMatch(s.trim());

  @override
  Widget build(BuildContext context) {
    final cols = block.columns.length;
    return ShadCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: CardHeader(title: block.title, subtitle: block.subtitle),
        ),
        Table(
          columnWidths: {0: const FlexColumnWidth(1.6), if (cols > 3) 2: const FlexColumnWidth(1.6)},
          defaultColumnWidth: const FlexColumnWidth(1),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: AppColors.subtle,
                border: Border(
                    top: BorderSide(color: AppColors.border),
                    bottom: BorderSide(color: AppColors.border)),
              ),
              children: [
                for (var c = 0; c < cols; c++)
                  _cell(Text(block.columns[c], style: AppText.label),
                      right: c == cols - 1 && c > 0),
              ],
            ),
            for (var r = 0; r < block.rows.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: block.highlightRows.contains(r) ? const Color(0xFFFEF2F2) : null,
                  border: r == block.rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                children: [
                  for (var c = 0; c < cols; c++)
                    _cell(
                      Text(
                        c < block.rows[r].length ? block.rows[r][c] : '',
                        style: c == 0
                            ? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
                            : (c == cols - 1 && _isNumeric(c < block.rows[r].length ? block.rows[r][c] : ''))
                                ? AppText.mono(size: 12.5, color: AppColors.foreground, weight: FontWeight.w600)
                                : const TextStyle(fontSize: 13, color: AppColors.foreground),
                      ),
                      right: c == cols - 1 && c > 0,
                    ),
                ],
              ),
          ],
        ),
      ]),
    );
  }

  Widget _cell(Widget child, {bool right = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: child),
      );
}

// -------------------------------------------------------------- actions ----

class ActionsView extends StatelessWidget {
  const ActionsView({super.key, required this.block, required this.onAction});
  final ActionsBlock block;
  final void Function(ActionsBlock, ActionItem) onAction;

  @override
  Widget build(BuildContext context) {
    final chosen = block.chosenId;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (block.title != null) ...[
        Text(block.title!.toUpperCase(), style: AppText.label.copyWith(fontSize: 10.5)),
        const SizedBox(height: 8),
      ],
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final a in block.actions)
          ShadButton(
            label: a.label,
            icon: chosen == a.id ? Icons.check_rounded : actionIcon(a.icon),
            variant: chosen == null
                ? parseVariant(a.variant)
                : (chosen == a.id ? ButtonVariant.secondary : ButtonVariant.ghost),
            onPressed: chosen == null
                ? () => onAction(block, a)
                : (chosen == a.id ? () {} : null),
          ),
      ]),
    ]);
  }
}
