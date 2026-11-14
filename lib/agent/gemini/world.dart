import 'dart:math' as math;

/// Result of a data tool: a compact [summary] for the model, a one-line
/// [detail] for the step list, and ready-made UI [blocks] keyed by data_id.
class ToolResult {
  ToolResult(this.summary, {this.detail, this.blocks = const {}});
  final Map<String, dynamic> summary;
  final String? detail;
  final Map<String, Map<String, dynamic>> blocks;

  Map<String, dynamic> toResponse() => {
        ...summary,
        if (blocks.isNotEmpty)
          'data_ids': {
            for (final e in blocks.entries) e.key: e.value['type'],
          },
      };
}

/// Simulated multi-cloud estate of "Acme Shop". All data is fake but
/// consistent, and it reacts to executed actions.
class InfraWorld {
  bool rolledBack = false;
  bool gpuScaledToZero = false;
  bool dbRightsized = false;
  bool searchScaled = false;
  bool auditArchived = false;

  static final _hours =
      List.generate(24, (i) => '${((12 + i) % 24).toString().padLeft(2, '0')}:00');

  static const _p95 = [402.0, 388.0, 415.0, 431.0, 398.0, 376.0, 362.0, 391.0, 420.0, 1840.0, 1910.0, 1785.0, 1702.0, 1655.0, 1690.0, 1720.0, 1810.0, 1880.0, 1965.0, 2010.0, 1940.0, 1895.0, 1930.0, 1920.0];
  static const _p50 = [184.0, 176.0, 190.0, 195.0, 181.0, 170.0, 166.0, 178.0, 188.0, 912.0, 948.0, 880.0, 842.0, 820.0, 836.0, 851.0, 898.0, 931.0, 975.0, 1002.0, 960.0, 938.0, 955.0, 948.0];

  ToolResult call(String tool, Map<String, dynamic> args) => switch (tool) {
        'list_incidents' => listIncidents(),
        'get_service_map' => serviceMap(),
        'query_metric' => queryMetric('${args['metric'] ?? 'checkout_latency'}'),
        'get_latency_by_region' => latencyByRegion(),
        'get_slow_trace' => slowTrace(),
        'get_recent_changes' => recentChanges(),
        'get_incident_timeline' => incidentTimeline(),
        'get_business_impact' => businessImpact(),
        'get_slo_status' => sloStatus(),
        'forecast_revenue' => forecastRevenue(),
        'get_costs' => costs(),
        'execute_action' => execute('${args['action'] ?? ''}'),
        _ => ToolResult({'error': 'unknown tool $tool'}),
      };

  // ------------------------------------------------------------ incidents ----

  ToolResult listIncidents() => ToolResult({
        'incidents': [
          if (!rolledBack)
            {
              'id': 'INC-checkout',
              'severity': 'critical',
              'title': 'Checkout is slow in West Europe',
              'since': 'yesterday 21:06 (about 15 h)',
              'checkout_p95_ms': 1920,
              'slo_ms': 800,
              'affected_sessions': 18400,
              'revenue_at_risk_eur_per_day': 6300,
            },
          if (!searchScaled)
            {
              'id': 'INC-search',
              'severity': 'warning',
              'title': 'Search errors elevated (search-api on Azure)',
              'since': '47 min',
              'error_rate_pct': 1.8,
              'normal_error_rate_pct': 0.2,
            },
          if (!auditArchived)
            {
              'id': 'INC-storage',
              'severity': 'warning',
              'title': 'orders-db storage 86% full (Azure)',
              'days_until_full': 9,
            },
        ],
        'resolved_today': [if (rolledBack) 'INC-checkout', if (searchScaled) 'INC-search', if (auditArchived) 'INC-storage'],
      }, detail: '${(rolledBack ? 0 : 1) + (searchScaled ? 0 : 1) + (auditArchived ? 0 : 1)} open');

  ToolResult serviceMap() => ToolResult({
        'checkout_path': [
          {'service': 'storefront', 'provider': 'codesphere', 'region': 'fra-1', 'status': 'ok'},
          {'service': 'checkout-api', 'provider': 'aws', 'region': 'eu-central-1', 'status': rolledBack ? 'ok' : 'degraded'},
          {'service': 'payment-svc', 'provider': 'gcp', 'region': rolledBack ? 'europe-west3' : 'us-east1', 'status': rolledBack ? 'ok' : 'critical'},
          {'service': 'orders-db', 'provider': 'azure', 'region': 'westeurope', 'status': 'ok'},
        ],
        'hops': [
          {'from': 'storefront', 'to': 'checkout-api', 'latency_ms': 38},
          {'from': 'checkout-api', 'to': 'payment-svc', 'calls_per_checkout': 3, 'latency_ms_per_call': rolledBack ? 31 : 274},
          {'from': 'payment-svc', 'to': 'orders-db', 'latency_ms': rolledBack ? 12 : 96},
        ],
        'total_services': 38,
      }, detail: '4 services on the checkout path', blocks: {
        'service_map': {
          'type': 'topology',
          'title': 'Checkout request path',
          'subtitle': 'Live dependency map across 4 providers',
          'nodes': [
            {'id': 'web', 'label': 'storefront', 'provider': 'codesphere', 'region': 'fra-1', 'status': 'info'},
            {'id': 'checkout', 'label': 'checkout-api', 'provider': 'aws', 'region': 'eu-central-1', 'status': rolledBack ? 'info' : 'warning'},
            {'id': 'payment', 'label': 'payment-svc', 'provider': 'gcp', 'region': rolledBack ? 'europe-west3' : 'us-east1', 'status': rolledBack ? 'success' : 'critical'},
            {'id': 'orders', 'label': 'orders-db', 'provider': 'azure', 'region': 'westeurope', 'status': 'info'},
          ],
          'edges': [
            {'from': 'web', 'to': 'checkout', 'label': '38 ms', 'status': 'info'},
            {'from': 'checkout', 'to': 'payment', 'label': rolledBack ? '3× 31 ms' : '3× 274 ms', 'status': rolledBack ? 'info' : 'critical'},
            {'from': 'payment', 'to': 'orders', 'label': rolledBack ? '12 ms' : '96 ms', 'status': rolledBack ? 'info' : 'warning'},
          ],
        },
      });

  // -------------------------------------------------------------- metrics ----

  ToolResult queryMetric(String metric) {
    switch (metric) {
      case 'search_error_rate':
        final v = searchScaled
            ? [0.2, 0.2, 0.3, 0.2, 0.2, 0.3, 0.2, 0.3, 0.4, 0.6, 0.9, 1.1, 1.4, 1.5, 0.6, 0.3]
            : [0.2, 0.2, 0.3, 0.2, 0.2, 0.3, 0.2, 0.3, 0.4, 0.6, 0.9, 1.1, 1.4, 1.5, 1.7, 1.8];
        return ToolResult({
          'metric': 'search-api 5xx rate (%)',
          'window': 'last 2 h',
          'current': v.last,
          'normal': 0.2,
          'cause_hint': searchScaled ? 'autoscale limit raised to 8, recovering' : 'app service plan at instance limit 4/4 since lunch peak',
          'fix_cost_eur_per_month': 140,
        }, detail: 'current ${v.last}%', blocks: {
          'search_errors': {
            'type': 'line_chart',
            'title': 'search-api 5xx rate',
            'subtitle': 'Last 2 hours',
            'source': 'Azure Monitor',
            'unit': '%',
            'labels': List.generate(16, (i) => '${11 + (i * 8) ~/ 60}:${((i * 8) % 60).toString().padLeft(2, '0')}'),
            'series': [
              {'name': '5xx rate', 'values': v}
            ],
            'threshold': 1.0,
            'threshold_label': 'Alert 1%',
            'highlight_from': 8,
            'highlight_label': 'Instance limit reached',
            'highlight_severity': 'warning',
          },
        });
      case 'orders_db_storage':
        return ToolResult({
          'metric': 'orders-db storage',
          'used_gb': auditArchived ? 249 : 430,
          'capacity_gb': 500,
          'growth_gb_per_day': 7,
          'largest_tables_gb': {'audit_log': auditArchived ? 31 : 212, 'orders': 128, 'order_items': 71, 'other': 19},
          'note': auditArchived ? 'audit_log retention set to 90 days' : 'audit_log has no retention policy',
        }, detail: auditArchived ? '50% used' : '86% used', blocks: {
          'storage_tables': {
            'type': 'bar_chart',
            'title': 'Largest tables in orders-db',
            'source': 'Azure SQL',
            'unit': 'GB',
            'bars': [
              {'label': 'audit_log', 'sublabel': auditArchived ? '90-day retention' : 'no retention policy', 'value': auditArchived ? 31 : 212, 'highlight': !auditArchived},
              {'label': 'orders', 'sublabel': '14.2M rows', 'value': 128},
              {'label': 'order_items', 'sublabel': '41.8M rows', 'value': 71},
              {'label': 'other', 'sublabel': '38 tables', 'value': 19},
            ],
          },
        });
      case 'gpu_utilization':
        return ToolResult({
          'metric': 'gke-ml-pool GPU utilisation (%), last 14 days',
          'pool': '4× A100, running 24/7',
          'idle_share_pct': 92,
          'training_jobs_per_week': 2,
          'scale_to_zero_enabled': gpuScaledToZero,
          'savings_eur_per_month_if_scaled_to_zero': 4120,
        }, detail: '92% idle', blocks: {
          'gpu_utilization': {
            'type': 'line_chart',
            'title': 'GPU utilisation',
            'subtitle': 'Last 14 days · gke-ml-pool',
            'source': 'Cloud Monitoring',
            'unit': '%',
            'labels': List.generate(14, (i) => 'Nov ${i + 1}'),
            'series': [
              {'name': 'GPU util', 'values': [0, 0, 0, 0, 0, 2, 71, 3, 1, 0, 68, 2, 0, 1]}
            ],
          },
        });
      default: // checkout_latency
        final p95 = rolledBack ? [..._p95.sublist(0, 22), 690.0, 412.0] : _p95;
        final p50 = rolledBack ? [..._p50.sublist(0, 22), 330.0, 188.0] : _p50;
        return ToolResult({
          'metric': 'checkout latency (ms), West Europe, last 24 h hourly',
          'p95_before_21h': 400,
          'p95_now': p95.last,
          'p50_now': p50.last,
          'slo_p95_ms': 800,
          'step_change_at': 'yesterday 21:06',
          'traffic_change': 'none',
          'error_rate_change': 'none',
          if (rolledBack) 'note': 'rollback of payment-svc completed, latency back to normal',
        }, detail: 'p95 ${p95.last.round()} ms', blocks: {
          'checkout_latency': {
            'type': 'line_chart',
            'title': 'Checkout latency',
            'subtitle': 'Last 24 hours · West Europe',
            'source': 'AWS CloudWatch',
            'unit': 'ms',
            'labels': _hours,
            'series': [
              {'name': 'p95', 'values': p95},
              {'name': 'p50', 'values': p50},
            ],
            'threshold': 800,
            'threshold_label': 'SLO 800 ms',
            'highlight_from': 9,
            'highlight_label': 'After deploy #482',
          },
        });
    }
  }

  // ---------------------------------------------------------- regions etc ----

  ToolResult latencyByRegion() {
    const regions = ['West Europe', 'Central Europe', 'North Europe', 'UK', 'US East', 'US West', 'Asia Pacific'];
    const before = [410.0, 395.0, 380.0, 430.0, 520.0, 610.0, 890.0];
    const during = [1920.0, 1810.0, 1760.0, 1790.0, 305.0, 470.0, 1080.0];

    // Hour 9 = 21:00 yesterday (deploy #482). After a rollback only the last
    // two hours recover (22 = rollout in progress, 23 = now), like real data.
    double valueAt(int r, int h) {
      final double base;
      if (h < 9) {
        base = before[r];
      } else if (rolledBack && h == 23) {
        base = before[r];
      } else if (rolledBack && h == 22) {
        base = during[r] * 0.35 + before[r] * 0.65;
      } else {
        base = during[r];
      }
      return (base * (1 + 0.06 * math.sin(h * 1.7 + r))).roundToDouble();
    }

    return ToolResult({
      'metric': 'checkout p95 (ms) by customer region, last 24 h',
      'regions': [
        for (var r = 0; r < regions.length; r++)
          {
            'region': regions[r],
            'before_incident_ms': before[r],
            'during_incident_ms': during[r],
            'now_ms': rolledBack ? before[r] : during[r],
          },
      ],
      'eu_share_of_traffic_pct': 81,
      'slo_ms': 800,
      if (rolledBack) 'note': 'rollback completed within the last hour; history still shows the incident from 21:00',
    }, detail: '7 regions × 24 h', blocks: {
      'region_heatmap': {
        'type': 'heatmap',
        'title': 'Checkout p95 by region',
        'subtitle': rolledBack
            ? 'Last 24 hours · recovered after the rollback (right edge)'
            : 'Last 24 hours · hover a cell for details',
        'source': 'AWS CloudWatch',
        'unit': 'ms',
        'threshold': 800,
        'x_labels': _hours,
        'y_labels': regions,
        'values': [
          for (var r = 0; r < regions.length; r++) [for (var h = 0; h < 24; h++) valueAt(r, h)]
        ],
      },
    });
  }

  ToolResult slowTrace() {
    // The p95 sample of the last 24 h still comes from the incident window,
    // even after the rollback. Current traces are reported in the summary.
    const call = 274.0;
    final spans = [
      {'name': 'POST /checkout', 'provider': 'codesphere', 'start': 0, 'duration': 1920, 'depth': 0},
      {'name': 'checkout-api.handle', 'provider': 'aws', 'start': 38, 'duration': 1342, 'depth': 1},
      {'name': 'fraud-check', 'provider': 'aws', 'start': 52, 'duration': 96, 'depth': 2},
      for (var i = 0; i < 3; i++)
        {'name': 'payment.authorize #${i + 1}', 'provider': 'gcp', 'start': 160 + i * (call + 6), 'duration': call, 'depth': 2, 'highlight': true},
      {'name': 'orders-db.insert', 'provider': 'azure', 'start': 160 + 3 * (call + 6), 'duration': 214, 'depth': 2},
    ];
    return ToolResult({
      'trace': 'representative slow checkout (>= p95 of the last 24 h), customer in Frankfurt',
      'total_ms': 1920,
      'payment_authorize_calls': 3,
      'sequential': true,
      'per_call_ms': call,
      'per_call_ms_before_deploy_482': 31,
      'network_waiting_ms': 822,
      'span_breakdown_ms': {'payment.authorize (3x)': 822, 'TLS handshakes cross-region': 410, 'storefront render': 260, 'orders-db write': 214, 'checkout-api compute': 118, 'fraud-check': 96},
      if (rolledBack)
        'current_traces_after_rollback': {'total_ms_p95': 640, 'payment_authorize_per_call_ms': 31, 'network_waiting_ms': 93},
    }, detail: '1,284 slow traces sampled', blocks: {
      'slow_trace': {
        'type': 'waterfall',
        'title': 'POST /checkout',
        'subtitle': rolledBack
            ? 'Slow checkout from before the rollback · West Europe'
            : 'Representative slow checkout · West Europe',
        'source': 'Cloud Trace',
        'spans': spans,
      },
      'span_breakdown': {
        'type': 'bar_chart',
        'title': 'Where the time goes',
        'subtitle': rolledBack ? 'p95 trace during the incident' : 'p95 checkout trace, broken down by span',
        'source': 'Cloud Trace',
        'unit': 'ms',
        'bars': [
          {'label': 'payment.authorize ×3', 'sublabel': 'sequential · us-east1', 'value': 822, 'highlight': true},
          {'label': 'TLS handshakes', 'sublabel': 'cross-region, not reused', 'value': 410, 'highlight': true},
          {'label': 'storefront render', 'sublabel': 'codesphere · fra-1', 'value': 260},
          {'label': 'orders-db write', 'sublabel': 'azure · westeurope', 'value': 214},
          {'label': 'checkout-api compute', 'sublabel': 'aws · eu-central-1', 'value': 118},
          {'label': 'fraud-check', 'sublabel': 'aws · eu-central-1', 'value': 96},
        ],
      },
    });
  }

  ToolResult recentChanges() => ToolResult({
        'deploys_last_24h': [
          {'time': 'yesterday 21:04', 'id': '#482', 'service': 'payment-svc', 'change': 'region europe-west3 → us-east1', 'correlated_with': 'checkout latency step change at 21:06'},
          {'time': 'yesterday 16:31', 'id': '#481', 'service': 'storefront', 'change': 'new product carousel'},
          {'time': 'yesterday 10:12', 'id': '#480', 'service': 'checkout-api', 'change': 'Stripe SDK 14.1 → 14.2'},
          if (rolledBack) {'time': 'today', 'id': '#483', 'service': 'payment-svc', 'change': 'rollback to europe-west3 (by Stratus)'},
        ],
      }, detail: '${rolledBack ? 4 : 3} deploys', blocks: {
        'deploys_table': {
          'type': 'table',
          'title': 'Changes in production',
          'subtitle': 'Last 24 hours',
          'columns': ['Time', 'Deploy', 'Service', 'Change'],
          'rows': [
            if (rolledBack) ['today', '#483', 'payment-svc', 'Rollback to europe-west3'],
            ['21:04', '#482', 'payment-svc', 'Region europe-west3 → us-east1'],
            ['16:31', '#481', 'storefront', 'New product carousel'],
            ['10:12', '#480', 'checkout-api', 'Stripe SDK 14.1 → 14.2'],
          ],
          'highlight_rows': [rolledBack ? 1 : 0],
        },
      });

  ToolResult incidentTimeline() => ToolResult({
        'events': [
          'yesterday 21:04 deploy #482 moved payment-svc to us-east1',
          '21:06 checkout p95 jumps to 1.8 s in all EU regions',
          '21:12 alert checkout-latency-p95 fired, routed to #payments-oncall which was muted for the weekend, never acknowledged',
          '23:40 conversion drops 0.4 pp, payment-step abandonment +29%',
          '08:15 support tickets about slow payment +340%',
          '12:40 Stratus identified root cause',
          if (rolledBack) 'today: rollback executed, p95 back to ~410 ms',
        ],
      }, detail: '${rolledBack ? 7 : 6} key events', blocks: {
        'incident_timeline': {
          'type': 'timeline',
          'title': 'Incident timeline',
          'subtitle': 'Yesterday 21:04 until now',
          'events': [
            {'time': '21:04', 'title': 'Deploy #482 rolled out', 'provider': 'codesphere', 'detail': 'payment-svc region changed from `europe-west3` to `us-east1`.'},
            {'time': '21:06', 'title': 'Checkout p95 jumps to 1.8 s', 'provider': 'aws', 'severity': 'critical', 'detail': 'SLO of 800 ms breached in all EU regions.'},
            {'time': '21:12', 'title': 'Alert fired, not acknowledged', 'provider': 'aws', 'severity': 'warning', 'detail': 'Routed to #payments-oncall, which was muted for the weekend.'},
            {'time': '23:40', 'title': 'Conversion drops 0.4 pp', 'provider': 'codesphere', 'severity': 'warning', 'detail': 'Abandonment at the payment step rises by **+29%**.'},
            {'time': '08:15', 'title': 'Support tickets about slow payment', 'severity': 'warning', 'detail': '**+340%** compared to a normal Saturday morning.'},
            {'time': '12:40', 'title': 'Root cause identified by Stratus', 'severity': 'success', 'detail': 'Correlated the latency step change with deploy #482.'},
            if (rolledBack) {'time': 'now', 'title': 'Rollback completed', 'provider': 'codesphere', 'severity': 'success', 'detail': 'Checkout p95 back to **~410 ms**.'},
          ],
        },
      });

  // ------------------------------------------------------------- business ----

  ToolResult businessImpact() => ToolResult({
        'funnel_today_vs_last_saturday': {
          'cart': [12480, 12610],
          'shipping': [9860, 10020],
          'payment': [7940, 8310],
          'confirmed': [rolledBack ? 4260 : 4180, 5240],
        },
        'payment_to_confirmed_rate_pct_today': [rolledBack ? 53.7 : 52.6, 63.1],
        'completed_orders_change_pct_today': rolledBack ? -18.7 : -20.2,
        'revenue_at_risk_eur_per_day': rolledBack ? 0 : 6300,
        'support_tickets_change_pct': 340,
        if (rolledBack)
          'since_rollback': {
            'payment_to_confirmed_rate_pct': 62.8,
            'note': 'conversion back to normal for new sessions; today\'s totals still include the incident hours',
          },
      }, detail: 'storefront analytics', blocks: {
        'checkout_funnel': {
          'type': 'funnel',
          'title': 'Checkout funnel',
          'subtitle': rolledBack ? 'Today vs. last Saturday · incident hours included' : 'Today vs. last Saturday',
          'source': 'Storefront analytics',
          'value_label': 'Today',
          'compare_label': 'Last week',
          'steps': [
            {'label': 'Cart', 'value': 12480, 'compare': 12610},
            {'label': 'Shipping details', 'value': 9860, 'compare': 10020},
            {'label': 'Payment', 'value': 7940, 'compare': 8310},
            {'label': 'Order confirmed', 'value': rolledBack ? 4260 : 4180, 'compare': 5240},
          ],
        },
      });

  ToolResult sloStatus() => ToolResult({
        'slo': 'checkout p95 < 800 ms for 99.5% of minutes, 30-day window',
        'error_budget_used_pct': 78,
        'burn_rate': rolledBack ? 0.4 : 14.2,
        'hours_until_exhausted': rolledBack ? null : 19,
        'attainment_30d_pct': 99.1,
        'release_freeze_below_budget_pct': 25,
      }, detail: rolledBack ? 'burn rate normal' : 'burn rate 14.2×', blocks: {
        'slo_gauges': {
          'type': 'gauges',
          'items': [
            {'label': 'Error budget used', 'value': 0.78, 'display': '78%', 'caption': rolledBack ? 'Burn stopped' : 'Exhausted in ~19 h', 'severity': rolledBack ? 'warning' : 'critical'},
            {'label': 'Burn rate', 'value': rolledBack ? 0.05 : 0.95, 'display': rolledBack ? '0.4×' : '14.2×', 'caption': 'Sustainable is 1×', 'severity': rolledBack ? 'success' : 'critical'},
            {'label': 'SLO attainment (30 d)', 'value': 0.62, 'display': '99.1%', 'caption': 'Target 99.5%', 'severity': 'warning'},
          ],
        },
        'error_budget_burn': {
          'type': 'line_chart',
          'title': 'Error budget remaining',
          'subtitle': 'Checkout latency SLO · dashed = projection',
          'source': 'SLO monitor',
          'unit': '%',
          'labels': List.generate(31, (i) {
            final d = DateTime(2026, 10, 16).add(Duration(days: i));
            return '${d.month == 10 ? 'Oct' : 'Nov'} ${d.day}';
          }),
          'series': [
            {
              'name': 'Budget left',
              'values': [100, 99, 99, 98, 98, 97, 97, 96, 96, 95, 95, 94, 94, 93, 93, 92, 92, 91, 91, 90, 90, 89, 89, 88, 88, 88, 87, 87, 86, 22, rolledBack ? 21 : 0],
              'dashed_from': 29,
            }
          ],
          'threshold': 25,
          'threshold_label': 'Release freeze below 25%',
          'highlight_from': 29,
          'highlight_label': 'Incident',
        },
      });

  ToolResult forecastRevenue() {
    final labels = List.generate(21, (i) => 'Nov ${10 + i}');
    final expected = <double>[
      for (var i = 0; i < 21; i++)
        (switch (10 + i) {
          27 => 260000.0,
          28 => 190000.0,
          29 => 150000.0,
          30 => 210000.0,
          _ => DateTime(2026, 11, 10 + i).weekday >= 6 ? 64000.0 : 58000.0,
        })
    ];
    final unfixed = <double>[
      for (var i = 0; i < 21; i++) i < 3 ? expected[i] : (i == 3 ? expected[i] * 0.95 : expected[i] * 0.89)
    ];
    return ToolResult({
      'assumption': 'conversion stays 11% lower until fixed; Black Friday traffic about 4.5x a normal day',
      'today': 'Nov 14',
      'black_friday': 'Nov 27 (weekend until Cyber Monday Nov 30)',
      'loss_until_black_friday_eur': 84000,
      'loss_black_friday_weekend_eur': 89000,
      'total_loss_by_nov_30_eur': 173000,
      if (rolledBack) 'note': 'incident already fixed, these losses are avoided',
    }, detail: 'projection to Nov 30', blocks: {
      'revenue_projection': {
        'type': 'line_chart',
        'title': 'Daily revenue',
        'subtitle': 'Dashed = projection from today',
        'source': 'Storefront analytics',
        'unit': '€',
        'labels': labels,
        'series': [
          {'name': 'With fix', 'values': expected, 'dashed_from': 4, 'color': '#16A34A'},
          {'name': 'Without fix', 'values': unfixed, 'dashed_from': 4, 'color': '#DC2626'},
        ],
        'highlight_from': 17,
        'highlight_label': 'Black Friday → Cyber Monday',
        'highlight_severity': 'warning',
      },
    });
  }

  // ---------------------------------------------------------------- costs ----

  ToolResult costs() {
    final opportunities = [
      if (!gpuScaledToZero)
        ['gke-ml-pool (4× A100)', 'Google Cloud', 'Idle 92% of the time since Nov 6', '€4,120'],
      if (!dbRightsized)
        ['orders-db-prod (r6g.4xlarge)', 'AWS', 'CPU avg 6%, memory 18%', '€3,240'],
      if (!rolledBack)
        ['Cross-cloud egress', 'GCP → Azure', 'payment-svc in us-east1 ↔ orders-db', '€2,960'],
      ['47 unattached volumes', 'Azure', 'Detached for > 30 days', '€1,080'],
    ];
    final saved = (gpuScaledToZero ? 4120 : 0) + (dbRightsized ? 3240 : 0) + (rolledBack ? 2960 : 0);
    return ToolResult({
      'month_to_date_eur': 30800,
      'forecast_eur': 52900 - saved,
      'budget_eur': 48200,
      'forecast_by_provider_eur': {'aws': 21400, 'gcp': 17850, 'azure': 9200, 'codesphere': 4450},
      'daily_spend_jump': 'Nov 6: +€600/day when the GPU pool was added',
      'open_savings_eur_per_month': 11400 - saved,
      'already_saved_eur_per_month': saved,
      'opportunities': opportunities,
    }, detail: '903 resources analysed', blocks: {
      'cost_by_provider': {
        'type': 'bar_chart',
        'title': 'Forecast by provider',
        'subtitle': 'November, projected',
        'unit': '€',
        'bars': [
          {'label': 'AWS', 'sublabel': '388 resources', 'value': 21400},
          {'label': 'Google Cloud', 'sublabel': '301 resources', 'value': 17850, 'highlight': true},
          {'label': 'Azure', 'sublabel': '214 resources', 'value': 9200},
          {'label': 'codesphere', 'sublabel': '12 workspaces', 'value': 4450},
        ],
      },
      'daily_spend': {
        'type': 'line_chart',
        'title': 'Daily spend',
        'subtitle': 'November, all providers',
        'source': 'Billing exports',
        'unit': '€',
        'labels': List.generate(14, (i) => 'Nov ${i + 1}'),
        'series': [
          {'name': 'Spend', 'values': [1610, 1590, 1620, 1650, 1700, 2280, 2310, 2290, 2350, 2400, 2380, 2420, 2390, 2410]}
        ],
        'threshold': 1750,
        'threshold_label': 'Budget pace',
        'highlight_from': 5,
        'highlight_label': 'GPU pool added',
        'highlight_severity': 'warning',
      },
      'savings_table': {
        'type': 'table',
        'title': 'Savings opportunities',
        'subtitle': 'Sorted by monthly impact',
        'columns': ['Resource', 'Provider', 'Issue', 'Savings / mo'],
        'rows': opportunities,
      },
    });
  }

  // -------------------------------------------------------------- actions ----

  static const actions = [
    'rollback_payment_svc',
    'scale_gpu_pool_to_zero',
    'rightsize_orders_db',
    'raise_search_autoscale',
    'archive_audit_logs',
    'open_incident_ticket',
  ];

  /// Provider that executes an action (for the step badge).
  static String? actionProvider(String action) => switch (action) {
        'rollback_payment_svc' => 'codesphere',
        'scale_gpu_pool_to_zero' => 'gcp',
        'rightsize_orders_db' => 'aws',
        'raise_search_autoscale' || 'archive_audit_logs' => 'azure',
        _ => null,
      };

  ToolResult execute(String action) {
    switch (action) {
      case 'rollback_payment_svc':
        rolledBack = true;
        return ToolResult({
          'status': 'done',
          'steps': ['deployed payment-svc@481 to europe-west3', 'shifted traffic 10% → 100%', 'verified checkout p95 412 ms', 'scaled down us-east1'],
          'checkout_p95_ms_now': 412,
          'downtime_s': 0,
          'egress_saved_eur_per_month': 2960,
        }, detail: 'p95 412 ms', blocks: {
          'rollback_recovery': {
            'type': 'line_chart',
            'title': 'Checkout p95 during rollback',
            'subtitle': 'Last 30 minutes',
            'source': 'AWS CloudWatch',
            'unit': 'ms',
            'labels': ['13:00', '13:02', '13:04', '13:06', '13:08', '13:10', '13:12', '13:14', '13:16', '13:18', '13:20', '13:22', '13:24', '13:26', '13:28'],
            'series': [
              {'name': 'p95', 'values': [1910, 1885, 1930, 1900, 1870, 1940, 1260, 690, 452, 421, 415, 409, 412, 405, 411]}
            ],
            'threshold': 800,
            'threshold_label': 'SLO 800 ms',
            'highlight_from': 6,
            'highlight_label': 'Rollback',
            'highlight_severity': 'success',
          },
        });
      case 'scale_gpu_pool_to_zero':
        gpuScaledToZero = true;
        return ToolResult({'status': 'done', 'nodes': '4 → 0 (auto-start when a training job is queued)', 'savings_eur_per_month': 4120},
            detail: '4 → 0 nodes');
      case 'rightsize_orders_db':
        dbRightsized = true;
        return ToolResult({
          'status': 'scheduled',
          'when': 'Sunday 03:00 (maintenance window)',
          'from': 'db.r6g.4xlarge (16 vCPU / 128 GB)',
          'to': 'db.r6g.xlarge (4 vCPU / 32 GB)',
          'projected_peak_cpu_pct': 68,
          'savings_eur_per_month': 3240,
        }, detail: 'scheduled Sun 03:00');
      case 'raise_search_autoscale':
        searchScaled = true;
        return ToolResult({'status': 'done', 'autoscale_max': '4 → 8 instances', 'instances_running': 6, 'error_rate_pct_now': 0.3, 'cost_eur_per_month': 140},
            detail: '6 instances running');
      case 'archive_audit_logs':
        auditArchived = true;
        return ToolResult({'status': 'done', 'freed_gb': 181, 'storage_used_pct_now': 50, 'retention': '90 days'},
            detail: '181 GB freed');
      case 'open_incident_ticket':
        return ToolResult({'status': 'done', 'ticket': 'INC-2041', 'notified': 'payment-svc on-call + #incidents'},
            detail: 'INC-2041');
      default:
        return ToolResult({'error': 'unknown action "$action", use one of $actions'});
    }
  }
}
