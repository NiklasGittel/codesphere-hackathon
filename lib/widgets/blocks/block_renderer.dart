import 'package:flutter/material.dart';

import '../../models/ui_block.dart';
import 'basic_blocks.dart';
import 'line_chart_card.dart';
import 'rich_blocks.dart';

/// Maps a [UiBlock] (from the agent) to its widget.
class BlockRenderer extends StatelessWidget {
  const BlockRenderer({super.key, required this.block, required this.onAction});
  final UiBlock block;
  final void Function(ActionsBlock, ActionItem) onAction;

  @override
  Widget build(BuildContext context) => switch (block) {
        StatsBlock b => StatsView(block: b),
        LineChartBlock b => LineChartCard(block: b),
        BarChartBlock b => BarChartCard(block: b),
        TopologyBlock b => TopologyCard(block: b),
        FindingBlock b => FindingView(block: b),
        TableBlock b => TableCard(block: b),
        ActionsBlock b => ActionsView(block: b, onAction: onAction),
        BriefBlock b => BriefView(block: b),
      };
}
