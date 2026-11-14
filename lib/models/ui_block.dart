import 'package:flutter/painting.dart';

/// Generative UI blocks.
///
/// Every block can be built from JSON via [UiBlock.fromJson]. This is the
/// contract between the agent (mock today, Gemini function calls later) and
/// the client: the model calls e.g. `render_ui({"type": "line_chart", ...})`
/// and the client renders the matching component.
enum Severity { info, success, warning, critical }

Severity parseSeverity(dynamic v) => Severity.values
    .firstWhere((s) => s.name == v, orElse: () => Severity.info);

List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

List<String> _strings(dynamic v) =>
    (v as List? ?? const []).map((e) => e.toString()).toList();

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

String? _str(dynamic v) => v?.toString();

Color? _color(dynamic v) {
  if (v is! String) return null;
  final hex = v.replaceFirst('#', '');
  final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return value == null ? null : Color(value);
}

sealed class UiBlock {
  const UiBlock();

  factory UiBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    switch (type) {
      case 'stats':
        return StatsBlock.fromJson(json);
      case 'line_chart':
        return LineChartBlock.fromJson(json);
      case 'bar_chart':
        return BarChartBlock.fromJson(json);
      case 'topology':
        return TopologyBlock.fromJson(json);
      case 'finding':
        return FindingBlock.fromJson(json);
      case 'table':
        return TableBlock.fromJson(json);
      case 'actions':
        return ActionsBlock.fromJson(json);
      case 'brief':
        return BriefBlock.fromJson(json);
      case 'heatmap':
        return HeatmapBlock.fromJson(json);
      case 'waterfall':
        return WaterfallBlock.fromJson(json);
      case 'funnel':
        return FunnelBlock.fromJson(json);
      case 'timeline':
        return TimelineBlock.fromJson(json);
      case 'gauges':
        return GaugesBlock.fromJson(json);
      case 'followups':
        return FollowUpsBlock.fromJson(json);
      default:
        return FindingBlock(
          title: 'Unknown component "$type"',
          body: 'The agent returned a component this client cannot render yet.',
          severity: Severity.warning,
        );
    }
  }
}

// ---------------------------------------------------------------- stats ----

class StatItem {
  const StatItem(
      {required this.label,
      required this.value,
      this.delta,
      this.good,
      this.hint});
  final String label;
  final String value;
  final String? delta;

  /// true = delta is good (green), false = bad (red), null = neutral.
  final bool? good;
  final String? hint;
}

class StatsBlock extends UiBlock {
  const StatsBlock({required this.items});
  final List<StatItem> items;

  factory StatsBlock.fromJson(Map<String, dynamic> j) => StatsBlock(
        items: _maps(j['items'])
            .map((m) => StatItem(
                  label: _str(m['label']) ?? '',
                  value: _str(m['value']) ?? '',
                  delta: _str(m['delta']),
                  good: m['good'] as bool?,
                  hint: _str(m['hint']),
                ))
            .toList(),
      );
}

// ----------------------------------------------------------- line chart ----

class ChartSeries {
  const ChartSeries(
      {required this.name, required this.values, this.color, this.dashedFrom});
  final String name;
  final List<double> values;
  final Color? color;

  /// Index from which the line is drawn dashed (projection / forecast).
  final int? dashedFrom;
}

class LineChartBlock extends UiBlock {
  const LineChartBlock({
    required this.title,
    required this.labels,
    required this.series,
    this.subtitle,
    this.source,
    this.unit = '',
    this.threshold,
    this.thresholdLabel,
    this.highlightFrom,
    this.highlightLabel,
    this.highlightSeverity = Severity.critical,
  });

  final String title;
  final String? subtitle;
  final String? source;
  final String unit;
  final List<String> labels;
  final List<ChartSeries> series;
  final double? threshold;
  final String? thresholdLabel;
  final int? highlightFrom;
  final String? highlightLabel;
  final Severity highlightSeverity;

  factory LineChartBlock.fromJson(Map<String, dynamic> j) => LineChartBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        source: _str(j['source']),
        unit: _str(j['unit']) ?? '',
        labels: _strings(j['labels']),
        series: _maps(j['series'])
            .map((s) => ChartSeries(
                  name: _str(s['name']) ?? '',
                  values: (s['values'] as List? ?? const [])
                      .map((v) => _num(v))
                      .toList(),
                  color: _color(s['color']),
                  dashedFrom: (s['dashed_from'] as num?)?.toInt(),
                ))
            .toList(),
        threshold: (j['threshold'] as num?)?.toDouble(),
        thresholdLabel: _str(j['threshold_label']),
        highlightFrom: (j['highlight_from'] as num?)?.toInt(),
        highlightLabel: _str(j['highlight_label']),
        highlightSeverity: j['highlight_severity'] == null
            ? Severity.critical
            : parseSeverity(j['highlight_severity']),
      );
}

// ------------------------------------------------------------ bar chart ----

class BarItem {
  const BarItem(
      {required this.label,
      required this.value,
      this.sublabel,
      this.highlight = false});
  final String label;
  final double value;
  final String? sublabel;
  final bool highlight;
}

class BarChartBlock extends UiBlock {
  const BarChartBlock(
      {required this.title,
      required this.bars,
      this.subtitle,
      this.source,
      this.unit = ''});
  final String title;
  final String? subtitle;
  final String? source;
  final String unit;
  final List<BarItem> bars;

  factory BarChartBlock.fromJson(Map<String, dynamic> j) => BarChartBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        source: _str(j['source']),
        unit: _str(j['unit']) ?? '',
        bars: _maps(j['bars'])
            .map((b) => BarItem(
                  label: _str(b['label']) ?? '',
                  value: _num(b['value']),
                  sublabel: _str(b['sublabel']),
                  highlight: b['highlight'] == true,
                ))
            .toList(),
      );
}

// ------------------------------------------------------------- topology ----

class TopoNode {
  const TopoNode(
      {required this.id,
      required this.label,
      this.provider,
      this.region,
      this.status = Severity.info});
  final String id;
  final String label;
  final String? provider;
  final String? region;
  final Severity status;
}

class TopoEdge {
  const TopoEdge(
      {required this.from,
      required this.to,
      this.label,
      this.status = Severity.info});
  final String from;
  final String to;
  final String? label;
  final Severity status;
}

class TopologyBlock extends UiBlock {
  const TopologyBlock(
      {required this.title,
      required this.nodes,
      required this.edges,
      this.subtitle});
  final String title;
  final String? subtitle;
  final List<TopoNode> nodes;
  final List<TopoEdge> edges;

  TopoEdge? edgeBetween(String from, String to) {
    for (final e in edges) {
      if (e.from == from && e.to == to) return e;
    }
    return null;
  }

  factory TopologyBlock.fromJson(Map<String, dynamic> j) => TopologyBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        nodes: _maps(j['nodes'])
            .map((n) => TopoNode(
                  id: _str(n['id']) ?? '',
                  label: _str(n['label']) ?? '',
                  provider: _str(n['provider']),
                  region: _str(n['region']),
                  status: parseSeverity(n['status']),
                ))
            .toList(),
        edges: _maps(j['edges'])
            .map((e) => TopoEdge(
                  from: _str(e['from']) ?? '',
                  to: _str(e['to']) ?? '',
                  label: _str(e['label']),
                  status: parseSeverity(e['status']),
                ))
            .toList(),
      );
}

// -------------------------------------------------------------- finding ----

class FindingBlock extends UiBlock {
  const FindingBlock(
      {required this.title,
      required this.body,
      this.severity = Severity.info,
      this.evidence = const [],
      this.source});
  final String title;
  final String body;
  final Severity severity;
  final List<String> evidence;
  final String? source;

  factory FindingBlock.fromJson(Map<String, dynamic> j) => FindingBlock(
        title: _str(j['title']) ?? '',
        body: _str(j['body']) ?? '',
        severity: parseSeverity(j['severity']),
        evidence: _strings(j['evidence']),
        source: _str(j['source']),
      );
}

// ---------------------------------------------------------------- table ----

class TableBlock extends UiBlock {
  const TableBlock(
      {required this.title,
      required this.columns,
      required this.rows,
      this.subtitle,
      this.highlightRows = const {}});
  final String title;
  final String? subtitle;
  final List<String> columns;
  final List<List<String>> rows;
  final Set<int> highlightRows;

  factory TableBlock.fromJson(Map<String, dynamic> j) => TableBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        columns: _strings(j['columns']),
        rows: (j['rows'] as List? ?? const []).map(_strings).toList(),
        highlightRows: (j['highlight_rows'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toSet(),
      );
}

// -------------------------------------------------------------- actions ----

class ActionItem {
  const ActionItem(
      {required this.id,
      required this.label,
      this.variant = 'outline',
      this.icon});
  final String id;
  final String label;

  /// primary | secondary | outline | ghost | destructive
  final String variant;
  final String? icon;
}

class ActionsBlock extends UiBlock {
  ActionsBlock({required this.actions, this.title});
  final String? title;
  final List<ActionItem> actions;

  /// Set once the user picked one of the actions.
  String? chosenId;

  factory ActionsBlock.fromJson(Map<String, dynamic> j) => ActionsBlock(
        title: _str(j['title']),
        actions: _maps(j['actions'])
            .map((a) => ActionItem(
                  id: _str(a['id']) ?? '',
                  label: _str(a['label']) ?? '',
                  variant: _str(a['variant']) ?? 'outline',
                  icon: _str(a['icon']),
                ))
            .toList(),
      );
}

// ---------------------------------------------------------------- brief ----

/// Concise problem breakdown shown first: what / impact / cause / fix.
class BriefItem {
  const BriefItem({required this.label, required this.text});
  final String label;
  final String text;
}

class BriefBlock extends UiBlock {
  const BriefBlock(
      {required this.title,
      required this.items,
      this.severity = Severity.info,
      this.badge});
  final String title;
  final Severity severity;
  final String? badge;
  final List<BriefItem> items;

  factory BriefBlock.fromJson(Map<String, dynamic> j) => BriefBlock(
        title: _str(j['title']) ?? '',
        severity: parseSeverity(j['severity']),
        badge: _str(j['badge']),
        items: _maps(j['items'])
            .map((m) => BriefItem(
                label: _str(m['label']) ?? '', text: _str(m['text']) ?? ''))
            .toList(),
      );
}

// -------------------------------------------------------------- heatmap ----

/// Grid of values, e.g. latency by region (rows) × hour (columns).
class HeatmapBlock extends UiBlock {
  const HeatmapBlock({
    required this.title,
    required this.xLabels,
    required this.yLabels,
    required this.values,
    this.subtitle,
    this.source,
    this.unit = '',
    this.threshold,
  });
  final String title;
  final String? subtitle;
  final String? source;
  final String unit;
  final List<String> xLabels;
  final List<String> yLabels;
  final List<List<double>> values;

  /// Values above this are drawn in the "bad" colour range.
  final double? threshold;

  factory HeatmapBlock.fromJson(Map<String, dynamic> j) => HeatmapBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        source: _str(j['source']),
        unit: _str(j['unit']) ?? '',
        xLabels: _strings(j['x_labels']),
        yLabels: _strings(j['y_labels']),
        values: (j['values'] as List? ?? const [])
            .map((r) => (r as List).map(_num).toList())
            .toList(),
        threshold: (j['threshold'] as num?)?.toDouble(),
      );
}

// ------------------------------------------------------------ waterfall ----

class TraceSpan {
  const TraceSpan({
    required this.name,
    required this.start,
    required this.duration,
    this.service,
    this.provider,
    this.depth = 0,
    this.highlight = false,
  });
  final String name;
  final String? service;
  final String? provider;
  final double start;
  final double duration;
  final int depth;
  final bool highlight;
}

/// Distributed trace of a single request.
class WaterfallBlock extends UiBlock {
  const WaterfallBlock(
      {required this.title, required this.spans, this.subtitle, this.source});
  final String title;
  final String? subtitle;
  final String? source;
  final List<TraceSpan> spans;

  double get total => spans.fold<double>(
      0, (m, s) => s.start + s.duration > m ? s.start + s.duration : m);

  factory WaterfallBlock.fromJson(Map<String, dynamic> j) => WaterfallBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        source: _str(j['source']),
        spans: _maps(j['spans'])
            .map((s) => TraceSpan(
                  name: _str(s['name']) ?? '',
                  service: _str(s['service']),
                  provider: _str(s['provider']),
                  start: _num(s['start']),
                  duration: _num(s['duration']),
                  depth: (s['depth'] as num?)?.toInt() ?? 0,
                  highlight: s['highlight'] == true,
                ))
            .toList(),
      );
}

// --------------------------------------------------------------- funnel ----

class FunnelStep {
  const FunnelStep({required this.label, required this.value, this.compare});
  final String label;
  final double value;
  final double? compare;
}

class FunnelBlock extends UiBlock {
  const FunnelBlock({
    required this.title,
    required this.steps,
    this.subtitle,
    this.source,
    this.valueLabel = 'Today',
    this.compareLabel,
  });
  final String title;
  final String? subtitle;
  final String? source;
  final String valueLabel;
  final String? compareLabel;
  final List<FunnelStep> steps;

  factory FunnelBlock.fromJson(Map<String, dynamic> j) => FunnelBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        source: _str(j['source']),
        valueLabel: _str(j['value_label']) ?? 'Today',
        compareLabel: _str(j['compare_label']),
        steps: _maps(j['steps'])
            .map((s) => FunnelStep(
                  label: _str(s['label']) ?? '',
                  value: _num(s['value']),
                  compare: (s['compare'] as num?)?.toDouble(),
                ))
            .toList(),
      );
}

// ------------------------------------------------------------- timeline ----

class TimelineEvent {
  const TimelineEvent({
    required this.time,
    required this.title,
    this.detail,
    this.provider,
    this.severity = Severity.info,
  });
  final String time;
  final String title;
  final String? detail;
  final String? provider;
  final Severity severity;
}

class TimelineBlock extends UiBlock {
  const TimelineBlock({required this.title, required this.events, this.subtitle});
  final String title;
  final String? subtitle;
  final List<TimelineEvent> events;

  factory TimelineBlock.fromJson(Map<String, dynamic> j) => TimelineBlock(
        title: _str(j['title']) ?? '',
        subtitle: _str(j['subtitle']),
        events: _maps(j['events'])
            .map((e) => TimelineEvent(
                  time: _str(e['time']) ?? '',
                  title: _str(e['title']) ?? '',
                  detail: _str(e['detail']),
                  provider: _str(e['provider']),
                  severity: parseSeverity(e['severity']),
                ))
            .toList(),
      );
}

// --------------------------------------------------------------- gauges ----

class GaugeItem {
  const GaugeItem({
    required this.label,
    required this.value,
    required this.display,
    this.caption,
    this.severity = Severity.info,
  });
  final String label;

  /// Fill of the arc, 0..1.
  final double value;
  final String display;
  final String? caption;
  final Severity severity;
}

class GaugesBlock extends UiBlock {
  const GaugesBlock({required this.items});
  final List<GaugeItem> items;

  factory GaugesBlock.fromJson(Map<String, dynamic> j) => GaugesBlock(
        items: _maps(j['items'])
            .map((g) => GaugeItem(
                  label: _str(g['label']) ?? '',
                  value: _num(g['value']).clamp(0, 1).toDouble(),
                  display: _str(g['display']) ?? '',
                  caption: _str(g['caption']),
                  severity: parseSeverity(g['severity']),
                ))
            .toList(),
      );
}

// ------------------------------------------------------------ follow-ups ----

/// Suggested next questions, rendered as clickable chips.
class FollowUpsBlock extends UiBlock {
  FollowUpsBlock({required this.questions, this.title});
  final String? title;
  final List<String> questions;
  final Set<String> asked = {};

  factory FollowUpsBlock.fromJson(Map<String, dynamic> j) => FollowUpsBlock(
        title: _str(j['title']),
        questions: _strings(j['questions']),
      );
}
