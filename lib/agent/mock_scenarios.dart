part of 'mock_agent.dart';

final _hours = List.generate(
    24, (i) => '${((12 + i) % 24).toString().padLeft(2, '0')}:00');

const _topology = {
  'type': 'topology',
  'title': 'Checkout request path',
  'subtitle': 'Live dependency map across 4 providers',
  'nodes': [
    {'id': 'web', 'label': 'storefront', 'provider': 'codesphere', 'region': 'fra-1', 'status': 'info'},
    {'id': 'checkout', 'label': 'checkout-api', 'provider': 'aws', 'region': 'eu-central-1', 'status': 'warning'},
    {'id': 'payment', 'label': 'payment-svc', 'provider': 'gcp', 'region': 'us-east1', 'status': 'critical'},
    {'id': 'orders', 'label': 'orders-db', 'provider': 'azure', 'region': 'westeurope', 'status': 'info'},
  ],
  'edges': [
    {'from': 'web', 'to': 'checkout', 'label': '38 ms', 'status': 'info'},
    {'from': 'checkout', 'to': 'payment', 'label': '3× 274 ms', 'status': 'critical'},
    {'from': 'payment', 'to': 'orders', 'label': '96 ms', 'status': 'warning'},
  ],
};

// ------------------------------------------------------------- checkout ----

Stream<AgentEvent> checkout(MockAgent a) async* {
  yield* a.step('intent', 'Understanding the question',
      ms: 450, detail: 'checkout · latency');
  yield* a.step('map', 'Mapping the checkout request path',
      source: 'codesphere', ms: 800, detail: '4 services');
  yield const StepStarted('metrics', 'Querying latency metrics', source: 'aws');
  await a.wait(150);
  yield const StepStarted('traces', 'Pulling distributed traces', source: 'gcp');
  await a.wait(150);
  yield const StepStarted('deploys', 'Checking recent deploys', source: 'codesphere');
  await a.wait(650);
  yield const StepCompleted('deploys', detail: '3 deploys / 24h');
  await a.wait(400);
  yield const StepCompleted('metrics', detail: '2,880 datapoints');
  await a.wait(500);
  yield const StepCompleted('traces', detail: '12,408 spans');
  yield* a.step('correlate', 'Correlating signals', ms: 900, detail: 'match found');

  yield* a.say(
      'Checkout got slow because of a **cross-region hop** introduced last night. Here is what I found:');
  await a.wait(200);
  yield a.ui({
    'type': 'stats',
    'items': [
      {'label': 'Checkout p95', 'value': '1.92 s', 'delta': '+357%', 'good': false},
      {'label': 'Conversion rate', 'value': '2.9%', 'delta': '−0.4 pp', 'good': false},
      {'label': 'Affected sessions', 'value': '18.4k', 'delta': 'last 14 h'},
      {'label': 'Revenue at risk', 'value': '€6.3k', 'delta': 'per day', 'good': false},
    ],
  });
  await a.wait(400);
  yield a.ui({
    'type': 'line_chart',
    'title': 'Checkout latency',
    'subtitle': 'Last 24 hours · all regions',
    'source': 'AWS CloudWatch',
    'unit': 'ms',
    'labels': _hours,
    'series': [
      {
        'name': 'p95',
        'values': [402, 388, 415, 431, 398, 376, 362, 391, 420, 1840, 1910, 1785, 1702, 1655, 1690, 1720, 1810, 1880, 1965, 2010, 1940, 1895, 1930, 1920],
      },
      {
        'name': 'p50',
        'values': [184, 176, 190, 195, 181, 170, 166, 178, 188, 912, 948, 880, 842, 820, 836, 851, 898, 931, 975, 1002, 960, 938, 955, 948],
      },
    ],
    'threshold': 800,
    'threshold_label': 'SLO 800 ms',
    'highlight_from': 9,
    'highlight_label': 'After deploy #482',
  });
  await a.wait(450);
  yield a.ui(_topology);
  await a.wait(450);
  yield a.ui({
    'type': 'bar_chart',
    'title': 'Where the time goes',
    'subtitle': 'p95 checkout trace, broken down by span',
    'source': 'Cloud Trace',
    'unit': 'ms',
    'bars': [
      {'label': 'payment.authorize', 'sublabel': '3 sequential calls · us-east1', 'value': 822, 'highlight': true},
      {'label': 'TLS handshakes', 'sublabel': 'cross-region, not reused', 'value': 410, 'highlight': true},
      {'label': 'storefront render', 'sublabel': 'codesphere · fra-1', 'value': 260},
      {'label': 'orders-db write', 'sublabel': 'azure · westeurope', 'value': 214},
      {'label': 'checkout-api compute', 'sublabel': 'aws · eu-central-1', 'value': 118},
      {'label': 'fraud-check', 'sublabel': 'aws · eu-central-1', 'value': 96},
    ],
  });
  await a.wait(450);
  yield a.ui({
    'type': 'finding',
    'severity': 'critical',
    'title': 'Root cause: payment-svc was moved to us-east1',
    'body':
        'Deploy **#482** (yesterday 21:04) changed the region of payment-svc from europe-west3 to us-east1. checkout-api calls it **3× sequentially** per checkout, which adds ~820 ms of transatlantic round-trips plus extra TLS handshakes.',
    'evidence': [
      'Latency step change at 21:06, two minutes after deploy #482',
      'payment.authorize p95 went from 31 ms to 274 ms per call',
      'No change in traffic volume or error rates before the deploy',
    ],
  });
  yield* a.say(
      'Rolling payment-svc back to europe-west3 should bring p95 back under the 800 ms SLO within minutes. How do you want to proceed?');
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'rollback', 'label': 'Roll back payment-svc to europe-west3', 'variant': 'primary', 'icon': 'rollback'},
      {'id': 'batch', 'label': 'Batch the 3 payment calls', 'variant': 'outline', 'icon': 'bolt'},
      {'id': 'ticket', 'label': 'Open incident', 'variant': 'ghost', 'icon': 'ticket'},
    ],
  });
}

Stream<AgentEvent> rollbackPlan(MockAgent a) async* {
  yield* a.step('plan', 'Generating rollback plan for deploy #482',
      source: 'codesphere', ms: 800, detail: 'payment-svc@481');
  yield* a.step('capacity', 'Checking capacity in europe-west3',
      source: 'gcp', ms: 700, detail: '34% headroom');
  yield* a.step('impact', 'Estimating impact', ms: 600);
  yield* a.say(
      'Here is the plan. It is a **blue/green rollback**, so there is no downtime:');
  yield a.ui({
    'type': 'table',
    'title': 'Rollback plan',
    'columns': ['Step', 'Target', 'ETA'],
    'rows': [
      ['Deploy payment-svc@481', 'gcp · europe-west3', '~2 min'],
      ['Shift traffic 10% → 50% → 100%', 'checkout-api', '~3 min'],
      ['Verify p95 < 800 ms', 'CloudWatch + Cloud Trace', '~1 min'],
      ['Scale down us-east1 instances', 'gcp · us-east1', '~1 min'],
    ],
  });
  yield a.ui({
    'type': 'stats',
    'items': [
      {'label': 'Projected p95', 'value': '~410 ms', 'delta': '−79%', 'good': true},
      {'label': 'Downtime', 'value': '0 s', 'delta': 'blue/green'},
      {'label': 'Egress saved', 'value': '€2,960', 'delta': 'per month', 'good': true},
    ],
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'confirm_rollback', 'label': 'Run rollback', 'variant': 'primary', 'icon': 'play'},
      {'id': 'cancel', 'label': 'Cancel', 'variant': 'ghost', 'icon': 'close'},
    ],
  });
}

Stream<AgentEvent> rollbackRun(MockAgent a) async* {
  yield* a.step('deploy', 'Deploying payment-svc@481 to europe-west3',
      source: 'codesphere', ms: 1500, detail: 'healthy');
  yield* a.step('shift', 'Shifting traffic 10% → 100%',
      source: 'gcp', ms: 1400, detail: '100%');
  yield* a.step('verify', 'Verifying checkout latency',
      source: 'aws', ms: 1000, detail: 'p95 412 ms');
  yield a.ui({
    'type': 'line_chart',
    'title': 'Checkout p95 during rollback',
    'subtitle': 'Last 30 minutes',
    'source': 'AWS CloudWatch',
    'unit': 'ms',
    'labels': ['11:50', '11:52', '11:54', '11:56', '11:58', '12:00', '12:02', '12:04', '12:06', '12:08', '12:10', '12:12', '12:14', '12:16', '12:18'],
    'series': [
      {'name': 'p95', 'values': [1910, 1885, 1930, 1900, 1870, 1940, 1260, 690, 452, 421, 415, 409, 412, 405, 411]},
    ],
    'threshold': 800,
    'threshold_label': 'SLO 800 ms',
    'highlight_from': 6,
    'highlight_label': 'Rollback',
    'highlight_severity': 'success',
  });
  yield a.ui({
    'type': 'finding',
    'severity': 'success',
    'title': 'Checkout is back to normal',
    'body':
        'p95 is now **412 ms** (SLO 800 ms). I will keep watching for the next hour and alert you if it regresses.',
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'ticket', 'label': 'Write postmortem draft', 'variant': 'outline', 'icon': 'export'},
    ],
  });
}

Stream<AgentEvent> batch(MockAgent a) async* {
  yield* a.step('code', 'Analysing checkout-api call pattern',
      source: 'aws', ms: 900, detail: '3 call sites');
  yield a.ui({
    'type': 'finding',
    'severity': 'info',
    'title': 'Batching needs a code change',
    'body':
        'The three `payment.authorize` calls can be merged into one `authorizeBatch` request. That saves ~550 ms even cross-region, but it needs a release of checkout-api. A rollback is faster right now.',
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'rollback', 'label': 'Roll back instead', 'variant': 'primary', 'icon': 'rollback'},
    ],
  });
}

Stream<AgentEvent> ticket(MockAgent a) async* {
  yield* a.step('incident', 'Creating incident with timeline and evidence',
      ms: 900, detail: 'INC-2041');
  yield a.ui({
    'type': 'finding',
    'severity': 'success',
    'title': 'Incident INC-2041 created',
    'body':
        'Timeline, charts and root-cause analysis are attached. The on-call team for payment-svc was notified.',
  });
}

// ---------------------------------------------------------------- costs ----

Stream<AgentEvent> costs(MockAgent a) async* {
  yield* a.step('intent', 'Understanding the question',
      ms: 400, detail: 'cost optimisation');
  yield const StepStarted('aws', 'Fetching AWS Cost Explorer', source: 'aws');
  await a.wait(120);
  yield const StepStarted('gcp', 'Fetching GCP billing export', source: 'gcp');
  await a.wait(120);
  yield const StepStarted('azure', 'Fetching Azure Cost Management', source: 'azure');
  await a.wait(120);
  yield const StepStarted('cs', 'Fetching codesphere usage', source: 'codesphere');
  await a.wait(500);
  yield const StepCompleted('cs', detail: '12 workspaces');
  await a.wait(300);
  yield const StepCompleted('azure', detail: '214 resources');
  await a.wait(300);
  yield const StepCompleted('aws', detail: '388 resources');
  await a.wait(300);
  yield const StepCompleted('gcp', detail: '301 resources');
  yield* a.step('util', 'Joining with utilisation metrics',
      ms: 800, detail: '903 resources');
  yield* a.step('waste', 'Detecting waste patterns', ms: 700, detail: '23 findings');

  yield* a.say(
      'You are on track to spend **€52.9k** this month, 9.7% over budget. I found **€11.4k/month** in savings, and most of them do not touch production performance.');
  yield a.ui({
    'type': 'stats',
    'items': [
      {'label': 'Month to date', 'value': '€30.8k', 'delta': 'Nov 1 – 14'},
      {'label': 'Forecast', 'value': '€52.9k', 'delta': '+9.7% vs budget', 'good': false},
      {'label': 'Savings found', 'value': '€11.4k', 'delta': '−21.6% / month', 'good': true},
      {'label': 'Wasteful resources', 'value': '23', 'delta': 'across 3 clouds'},
    ],
  });
  await a.wait(350);
  yield a.ui({
    'type': 'line_chart',
    'title': 'Daily spend',
    'subtitle': 'November, all providers',
    'source': 'Billing exports',
    'unit': '€',
    'labels': List.generate(14, (i) => 'Nov ${i + 1}'),
    'series': [
      {'name': 'Spend', 'values': [1610, 1590, 1620, 1650, 1700, 2280, 2310, 2290, 2350, 2400, 2380, 2420, 2390, 2410]},
    ],
    'threshold': 1750,
    'threshold_label': 'Budget pace',
    'highlight_from': 5,
    'highlight_label': 'GPU pool added',
    'highlight_severity': 'warning',
  });
  await a.wait(350);
  yield a.ui({
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
  });
  await a.wait(350);
  yield a.ui({
    'type': 'table',
    'title': 'Top savings opportunities',
    'subtitle': 'Sorted by monthly impact',
    'columns': ['Resource', 'Provider', 'Issue', 'Savings / mo'],
    'rows': [
      ['gke-ml-pool (4× A100)', 'Google Cloud', 'Idle 92% of the time since Nov 6', '€4,120'],
      ['orders-db-prod (r6g.4xlarge)', 'AWS', 'CPU avg 6%, memory 18%', '€3,240'],
      ['Cross-cloud egress', 'GCP → Azure', 'payment-svc ↔ orders-db', '€2,960'],
      ['47 unattached volumes', 'Azure', 'Detached for > 30 days', '€1,080'],
    ],
    'highlight_rows': [0, 1],
  });
  yield* a.say(
      'The quickest win is the idle GPU pool. Scaling it to zero when no training job runs saves €4.1k without any risk.');
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'stop_gpus', 'label': 'Scale gke-ml-pool to zero', 'variant': 'primary', 'icon': 'stop'},
      {'id': 'rightsize', 'label': 'Rightsize orders-db', 'variant': 'outline', 'icon': 'resize'},
      {'id': 'ask_checkout', 'label': 'Explain the egress costs', 'variant': 'ghost', 'icon': 'bolt'},
    ],
  });
}

Stream<AgentEvent> stopGpus(MockAgent a) async* {
  yield* a.step('jobs', 'Checking for running training jobs',
      source: 'gcp', ms: 800, detail: 'none');
  yield* a.step('scale', 'Enabling scale-to-zero on gke-ml-pool',
      source: 'gcp', ms: 1200, detail: '4 → 0 nodes');
  yield a.ui({
    'type': 'finding',
    'severity': 'success',
    'title': 'gke-ml-pool now scales to zero',
    'body':
        'Nodes start automatically when a training job is queued. Estimated savings: **€4,120 / month**.',
  });
}

Stream<AgentEvent> rightsize(MockAgent a) async* {
  yield* a.step('analyze', 'Analysing 30 days of orders-db load',
      source: 'aws', ms: 1000, detail: 'peak CPU 21%');
  yield a.ui({
    'type': 'table',
    'title': 'Rightsizing proposal',
    'columns': ['', 'Current', 'Proposed'],
    'rows': [
      ['Instance', 'db.r6g.4xlarge', 'db.r6g.xlarge'],
      ['vCPU / RAM', '16 / 128 GB', '4 / 32 GB'],
      ['Peak CPU (projected)', '21%', '68%'],
      ['Cost / month', '€4,310', '€1,070'],
    ],
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'scheduled', 'label': 'Schedule for Sunday 03:00', 'variant': 'primary', 'icon': 'check'},
      {'id': 'cancel', 'label': 'Not now', 'variant': 'ghost', 'icon': 'close'},
    ],
  });
}

// -------------------------------------------------------------- changes ----

Stream<AgentEvent> changes(MockAgent a) async* {
  yield* a.step('deploys', 'Collecting deploys and config changes',
      source: 'codesphere', ms: 800, detail: '3 deploys');
  yield* a.step('infra', 'Diffing infrastructure state',
      source: 'gcp', ms: 700, detail: '1 region move');
  yield* a.step('correlate', 'Correlating with alerts', ms: 600, detail: '1 match');
  yield* a.say(
      'There were **3 deploys** in the last 24 hours. One of them lines up with a latency regression:');
  yield a.ui({
    'type': 'table',
    'title': 'Changes in production',
    'subtitle': 'Last 24 hours',
    'columns': ['Time', 'Deploy', 'Service', 'Change'],
    'rows': [
      ['21:04', '#482', 'payment-svc', 'Region europe-west3 → us-east1'],
      ['16:31', '#481', 'storefront', 'New product carousel'],
      ['10:12', '#480', 'checkout-api', 'Stripe SDK 14.1 → 14.2'],
    ],
    'highlight_rows': [0],
  });
  yield a.ui({
    'type': 'finding',
    'severity': 'warning',
    'title': 'Deploy #482 correlates with slower checkouts',
    'body':
        'Checkout p95 jumped from ~400 ms to ~1.9 s two minutes after this deploy.',
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'ask_checkout', 'label': 'Investigate checkout latency', 'variant': 'primary', 'icon': 'bolt'},
      {'id': 'rollback', 'label': 'Roll back #482', 'variant': 'outline', 'icon': 'rollback'},
    ],
  });
}

// ------------------------------------------------------------- overview ----

Stream<AgentEvent> overview(MockAgent a) async* {
  yield* a.step('intent', 'Understanding the question', ms: 400);
  yield* a.step('scan', 'Scanning all providers', ms: 1100, detail: '38 services');
  yield* a.say('Here is a snapshot of production across all four providers:');
  yield a.ui({
    'type': 'stats',
    'items': [
      {'label': 'Services', 'value': '38', 'delta': '4 providers'},
      {'label': 'Open alerts', 'value': '3', 'delta': '1 critical', 'good': false},
      {'label': 'Checkout p95', 'value': '1.92 s', 'delta': 'SLO breached', 'good': false},
      {'label': 'Monthly forecast', 'value': '€52.9k', 'delta': '+9.7% vs budget', 'good': false},
    ],
  });
  yield a.ui(_topology);
  yield a.ui({
    'type': 'actions',
    'title': 'Suggested next steps',
    'actions': [
      {'id': 'ask_checkout', 'label': 'Why is checkout slow?', 'variant': 'outline', 'icon': 'bolt'},
      {'id': 'ask_costs', 'label': 'Where can I save money?', 'variant': 'outline', 'icon': 'savings'},
    ],
  });
}
