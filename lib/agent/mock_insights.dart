part of 'mock_agent.dart';

/// Follow-up questions that each trigger a different generative-UI diagram.
const insightQuestions = [
  'Which regions are affected?',
  'Show me the trace of a slow checkout',
  'How does this affect conversion?',
  'What happened, step by step?',
  'How much error budget have we burned?',
  "What if we don't fix this before Black Friday?",
];

Map<String, dynamic> followups({String? exclude}) => {
      'type': 'followups',
      'title': 'Dig deeper',
      'questions': [for (final q in insightQuestions) if (q != exclude) q],
    };

// --------------------------------------------------- regions (heatmap) ----

Stream<AgentEvent> regions(MockAgent a) async* {
  yield* a.step('regions', 'Breaking down checkout latency by region', source: 'aws', ms: 800, detail: '7 regions × 24 h');
  yield* a.step('traffic', 'Joining with traffic per region', source: 'codesphere', ms: 600, detail: '81% EU traffic');
  yield* a.say(
      'Only **European** customers are affected. Every EU region crossed the SLO at 21:00. **US East actually got faster** (520 → 305 ms), because payment-svc now runs right next to it.');
  const before = [410.0, 395.0, 380.0, 430.0, 520.0, 610.0, 890.0];
  const after = [1920.0, 1810.0, 1760.0, 1790.0, 305.0, 470.0, 1080.0];
  yield a.ui({
    'type': 'heatmap',
    'title': 'Checkout p95 by region',
    'subtitle': 'Last 24 hours · hover a cell for details',
    'source': 'AWS CloudWatch',
    'unit': 'ms',
    'threshold': 800,
    'x_labels': _hours,
    'y_labels': ['West Europe', 'Central Europe', 'North Europe', 'UK', 'US East', 'US West', 'Asia Pacific'],
    'values': [
      for (var r = 0; r < 7; r++)
        [
          for (var h = 0; h < 24; h++)
            ((h < 9 ? before[r] : after[r]) * (1 + 0.06 * math.sin(h * 1.7 + r))).roundToDouble()
        ]
    ],
  });
  yield a.ui(followups(exclude: insightQuestions[0]));
}

// ------------------------------------------------------ trace (waterfall) ----

Stream<AgentEvent> trace(MockAgent a) async* {
  yield* a.step('sample', 'Sampling slow checkout traces (≥ p95)', source: 'gcp', ms: 800, detail: '1,284 traces');
  yield* a.step('pick', 'Picking a representative trace', ms: 600, detail: 'trace 7f3a…c21');
  yield* a.say('This is one checkout from a customer in Frankfurt, 1.92 s end to end:');
  yield a.ui({
    'type': 'waterfall',
    'title': 'POST /checkout',
    'subtitle': 'trace 7f3a…c21 · West Europe · 1.92 s',
    'source': 'Cloud Trace',
    'spans': [
      {'name': 'POST /checkout', 'provider': 'codesphere', 'start': 0, 'duration': 1920, 'depth': 0},
      {'name': 'checkout-api.handle', 'provider': 'aws', 'start': 38, 'duration': 1342, 'depth': 1},
      {'name': 'fraud-check', 'provider': 'aws', 'start': 52, 'duration': 96, 'depth': 2},
      {'name': 'payment.authorize #1', 'provider': 'gcp', 'start': 160, 'duration': 274, 'depth': 2, 'highlight': true},
      {'name': 'payment.authorize #2', 'provider': 'gcp', 'start': 440, 'duration': 274, 'depth': 2, 'highlight': true},
      {'name': 'payment.authorize #3', 'provider': 'gcp', 'start': 720, 'duration': 274, 'depth': 2, 'highlight': true},
      {'name': 'orders-db.insert', 'provider': 'azure', 'start': 1004, 'duration': 214, 'depth': 2},
      {'name': 'inventory.reserve', 'provider': 'aws', 'start': 1224, 'duration': 120, 'depth': 2},
      {'name': 'render confirmation', 'provider': 'codesphere', 'start': 1390, 'duration': 520, 'depth': 1},
    ],
  });
  yield a.ui({
    'type': 'finding',
    'severity': 'critical',
    'title': '43% of the request is waiting on the Atlantic',
    'body':
        'payment.authorize is called **3× in sequence**, and each call crosses to us-east1 (~274 ms instead of 31 ms). That is **822 ms** of pure network round-trips.',
  });
  yield a.ui(followups(exclude: insightQuestions[1]));
}

// ----------------------------------------------------- conversion (funnel) ----

Stream<AgentEvent> funnel(MockAgent a) async* {
  yield* a.step('funnel', 'Loading checkout funnel', source: 'codesphere', ms: 800, detail: 'storefront analytics');
  yield* a.step('compare', 'Comparing with the same weekday last week', ms: 600, detail: 'Sat Nov 7');
  yield* a.say(
      'Customers still get to the payment step, but **1 in 5 now give up while paying**. That is where the extra 1.5 s hits.');
  yield a.ui({
    'type': 'funnel',
    'title': 'Checkout funnel',
    'subtitle': 'Today vs. last Saturday',
    'source': 'Storefront analytics',
    'value_label': 'Today',
    'compare_label': 'Last week',
    'steps': [
      {'label': 'Cart', 'value': 12480, 'compare': 12610},
      {'label': 'Shipping details', 'value': 9860, 'compare': 10020},
      {'label': 'Payment', 'value': 7940, 'compare': 8310},
      {'label': 'Order confirmed', 'value': 4180, 'compare': 5240},
    ],
  });
  yield a.ui({
    'type': 'stats',
    'items': [
      {'label': 'Completed orders', 'value': '4,180', 'delta': '−20.2% vs last week', 'good': false},
      {'label': 'Abandoned at payment', 'value': '3,760', 'delta': '+1,090', 'good': false},
      {'label': 'Revenue at risk', 'value': '€6.3k', 'delta': 'per day', 'good': false},
    ],
  });
  yield a.ui(followups(exclude: insightQuestions[2]));
}

// ------------------------------------------------------ incident timeline ----

Stream<AgentEvent> timeline(MockAgent a) async* {
  yield* a.step('collect', 'Collecting deploys, alerts and metric changes', ms: 900, detail: '23 events');
  yield* a.step('order', 'Building the incident timeline', ms: 500, detail: '6 key events');
  yield a.ui({
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
    ],
  });
  yield a.ui({
    'type': 'finding',
    'severity': 'warning',
    'title': 'The alert fired 15 hours ago, but nobody saw it',
    'body': 'The on-call channel for payments was muted. Route `checkout-latency-p95` to the general incident channel as well.',
  });
  yield a.ui(followups(exclude: insightQuestions[3]));
}

// --------------------------------------------------- error budget (gauges) ----

Stream<AgentEvent> errorBudget(MockAgent a) async* {
  yield* a.step('slo', 'Reading SLO definitions', source: 'aws', ms: 600, detail: 'checkout-latency 99.5%');
  yield* a.step('burn', 'Calculating error budget burn', ms: 800, detail: '30-day window');
  yield* a.say('The checkout latency SLO is in serious trouble. At the current burn rate the **monthly error budget is gone by tomorrow morning**.');
  yield a.ui({
    'type': 'gauges',
    'items': [
      {'label': 'Error budget used', 'value': 0.78, 'display': '78%', 'caption': 'Exhausted in ~19 h', 'severity': 'critical'},
      {'label': 'Burn rate', 'value': 0.95, 'display': '14.2×', 'caption': 'Sustainable is 1×', 'severity': 'critical'},
      {'label': 'SLO attainment (30 d)', 'value': 0.62, 'display': '99.1%', 'caption': 'Target 99.5%', 'severity': 'warning'},
    ],
  });
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final days = List.generate(31, (i) {
    final d = DateTime(2026, 10, 16).add(Duration(days: i));
    return '${months[d.month - 1]} ${d.day}';
  });
  yield a.ui({
    'type': 'line_chart',
    'title': 'Error budget remaining',
    'subtitle': 'Checkout latency SLO · dashed = projection',
    'source': 'SLO monitor',
    'unit': '%',
    'labels': days,
    'series': [
      {
        'name': 'Budget left',
        'values': [100, 99, 99, 98, 98, 97, 97, 96, 96, 95, 95, 94, 94, 93, 93, 92, 92, 91, 91, 90, 90, 89, 89, 88, 88, 88, 87, 87, 86, 22, 0],
        'dashed_from': 29,
      },
    ],
    'threshold': 25,
    'threshold_label': 'Release freeze below 25%',
    'highlight_from': 29,
    'highlight_label': 'Incident',
  });
  yield a.ui(followups(exclude: insightQuestions[4]));
}

// ----------------------------------------------- Black Friday (projection) ----

Stream<AgentEvent> blackFriday(MockAgent a) async* {
  yield* a.step('history', 'Loading revenue from last year’s Black Friday', source: 'codesphere', ms: 700, detail: '4.5× normal');
  yield* a.step('model', 'Projecting revenue with and without a fix', ms: 900, detail: '−11% conversion');
  yield* a.say('If this stays unfixed, the loss gets **much bigger on Black Friday**, when traffic is about 4.5× a normal day:');
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
    for (var i = 0; i < 21; i++)
      i < 3 ? expected[i] : (i == 3 ? expected[i] * 0.95 : expected[i] * 0.89)
  ];
  yield a.ui({
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
  });
  yield a.ui({
    'type': 'stats',
    'items': [
      {'label': 'Lost until Black Friday', 'value': '€84k', 'delta': '13 days × €6.4k', 'good': false},
      {'label': 'Lost over BF weekend', 'value': '€89k', 'delta': '4 days', 'good': false},
      {'label': 'Total by Nov 30', 'value': '€173k', 'delta': 'avoidable today', 'good': false},
    ],
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'rollback', 'label': 'Fix it now: roll back payment-svc', 'variant': 'primary', 'icon': 'rollback'},
    ],
  });
  yield a.ui(followups(exclude: insightQuestions[5]));
}
