import 'world.dart';

String systemPrompt(DateTime now) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  return '''
You are Stratus, an AI SRE and FinOps agent for "Acme Shop", an online shop running on AWS, Google Cloud (gcp), Azure and codesphere. You investigate problems across all providers and explain them to busy engineers and managers. Today is ${weekdays[now.weekday - 1]}, ${now.day} Nov ${now.year}, $time. Black Friday is Nov 27.

HOW YOU WORK
1. Investigate with the data tools before answering. Call several tools in parallel when useful. Never invent numbers: only use numbers returned by tools.
2. Answer visually. The chat renders UI components that you create:
   - show_data(data_id): renders a ready-made visualization returned by a data tool (line charts, heatmaps, trace waterfalls, funnels, timelines, gauges, dependency maps, tables). Always prefer this for data a tool returned.
   - render_ui(component_json): renders a component you compose yourself (schemas below).
3. Structure:
   - New problem, incident or card the user opened: one `brief` (What / Impact / Cause / Fix), then the 2-3 most insightful visualizations as evidence, then `actions` with concrete next steps, then `followups` with 4-5 short questions the user could ask next.
   - Follow-up question: one or two sentences with the key insight, then the single most insightful visualization (two at most), then `followups`.
4. Text: at most 2 short sentences between components, plain prose, **bold** for key numbers. No headings, no bullet lists, no tables in text: use components instead. Do not repeat what a component already shows.
5. Buttons: when the user clicks a button you receive: User clicked the button "<label>" (action id: <id>). For changes to production, first render a short plan (a `table` or `brief`) and `actions` with a primary "Confirm" button (id "confirm:<action>") and a ghost "Cancel" button (id "cancel"). Call execute_action only after the user clicked a confirm button. Afterwards show the result (show_data for returned data_ids, otherwise a `finding` with severity success) and offer followups.
6. Available production actions for execute_action: ${InfraWorld.actions.join(', ')}.
7. If something is not covered by any tool, say so in one sentence and offer what you can show.
8. Answer in the language of the user.

COMPONENT SCHEMAS FOR render_ui (a JSON object string with "type")
- brief: {"type":"brief","severity":"critical|warning|success|info","title":"...","badge":"short tag like Ongoing · 15 h","items":[{"label":"What|Impact|Cause|Fix|Savings|Effort","text":"..."}]}
- stats: {"type":"stats","items":[{"label":"...","value":"...","delta":"...","good":true}]}  (good: true green, false red, omit = neutral)
- finding: {"type":"finding","severity":"critical|warning|success|info","title":"...","body":"...","evidence":["..."]}
- table: {"type":"table","title":"...","subtitle":"...","columns":["..."],"rows":[["..."]],"highlight_rows":[0]}
- bar_chart: {"type":"bar_chart","title":"...","subtitle":"...","unit":"ms|€|%|GB","bars":[{"label":"...","sublabel":"...","value":123,"highlight":true}]}
- line_chart: {"type":"line_chart","title":"...","unit":"ms|€|%","labels":["..."],"series":[{"name":"...","values":[1,2],"dashed_from":3}],"threshold":800,"threshold_label":"...","highlight_from":2,"highlight_label":"..."}
- actions: {"type":"actions","actions":[{"id":"...","label":"...","variant":"primary|outline|ghost|destructive","icon":"rollback|bolt|ticket|resize|stop|export|check|close|play|savings"}]}
- followups: {"type":"followups","questions":["...","..."]}
''';
}

/// Function declarations exposed to Gemini.
final functionDeclarations = <Map<String, dynamic>>[
  {'name': 'list_incidents', 'description': 'List open incidents across all clouds with severity and key numbers.'},
  {
    'name': 'get_service_map',
    'description': 'Dependency map of the checkout request path: services, providers, regions, hop latencies. data_id: service_map (topology).'
  },
  {
    'name': 'query_metric',
    'description': 'Metric details and time series. data_ids: checkout_latency (line chart), search_errors (line chart), storage_tables (bar chart), gpu_utilization (line chart).',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'metric': {
          'type': 'STRING',
          'enum': ['checkout_latency', 'search_error_rate', 'orders_db_storage', 'gpu_utilization'],
        },
      },
      'required': ['metric'],
    },
  },
  {'name': 'get_latency_by_region', 'description': 'Checkout p95 latency per customer region over the last 24 h. data_id: region_heatmap (heatmap).'},
  {'name': 'get_slow_trace', 'description': 'A representative slow checkout trace with all spans. data_ids: slow_trace (waterfall), span_breakdown (bar chart).'},
  {'name': 'get_recent_changes', 'description': 'Deploys and configuration changes in the last 24 h. data_id: deploys_table (table).'},
  {'name': 'get_incident_timeline', 'description': 'Chronological events of the checkout incident: deploy, latency jump, alert, business impact. data_id: incident_timeline (timeline).'},
  {'name': 'get_business_impact', 'description': 'Checkout funnel today vs last week, completed orders, revenue at risk. data_id: checkout_funnel (funnel).'},
  {'name': 'get_slo_status', 'description': 'Checkout latency SLO, error budget and burn rate. data_ids: slo_gauges (gauges), error_budget_burn (line chart with projection).'},
  {'name': 'forecast_revenue', 'description': 'Daily revenue projection until Cyber Monday with and without a fix, including Black Friday. data_id: revenue_projection (line chart).'},
  {'name': 'get_costs', 'description': 'Cloud spend, forecast vs budget and savings opportunities. data_ids: cost_by_provider (bar chart), daily_spend (line chart), savings_table (table).'},
  {
    'name': 'execute_action',
    'description': 'Execute a change in production. Only call this after the user clicked a confirm button.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'action': {'type': 'STRING', 'enum': InfraWorld.actions},
      },
      'required': ['action'],
    },
  },
  {
    'name': 'show_data',
    'description': 'Render a ready-made visualization in the chat. data_id must come from a data tool result in this conversation.',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'data_id': {'type': 'STRING'},
        'title': {'type': 'STRING', 'description': 'Optional title override'},
        'subtitle': {'type': 'STRING', 'description': 'Optional subtitle override'},
      },
      'required': ['data_id'],
    },
  },
  {
    'name': 'render_ui',
    'description': 'Render a UI component you compose yourself (brief, stats, finding, table, bar_chart, line_chart, actions, followups).',
    'parameters': {
      'type': 'OBJECT',
      'properties': {
        'component_json': {'type': 'STRING', 'description': 'The component as a JSON object string, see schemas in the system instructions.'},
      },
      'required': ['component_json'],
    },
  },
];

/// Step labels and provider badges for data tools.
String toolLabel(String name, Map<String, dynamic> args) => switch (name) {
      'list_incidents' => 'Listing open incidents',
      'get_service_map' => 'Mapping the checkout request path',
      'query_metric' => switch (args['metric']) {
          'search_error_rate' => 'Querying search-api error rate',
          'orders_db_storage' => 'Reading orders-db storage',
          'gpu_utilization' => 'Reading GPU utilisation',
          _ => 'Querying checkout latency',
        },
      'get_latency_by_region' => 'Breaking down latency by region',
      'get_slow_trace' => 'Pulling a slow checkout trace',
      'get_recent_changes' => 'Checking recent deploys',
      'get_incident_timeline' => 'Building the incident timeline',
      'get_business_impact' => 'Loading the checkout funnel',
      'get_slo_status' => 'Calculating error budget burn',
      'forecast_revenue' => 'Projecting revenue',
      'get_costs' => 'Fetching billing data from all clouds',
      'execute_action' => 'Executing ${'${args['action']}'.replaceAll('_', ' ')}',
      _ => name,
    };

String? toolSource(String name, Map<String, dynamic> args) => switch (name) {
      'get_service_map' || 'get_recent_changes' || 'get_business_impact' || 'forecast_revenue' => 'codesphere',
      'get_latency_by_region' || 'get_slo_status' => 'aws',
      'get_slow_trace' => 'gcp',
      'query_metric' => switch (args['metric']) {
          'search_error_rate' || 'orders_db_storage' => 'azure',
          'gpu_utilization' => 'gcp',
          _ => 'aws',
        },
      'execute_action' => InfraWorld.actionProvider('${args['action']}'),
      _ => null,
    };
