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
  yield* a.step('map', 'Mapping the checkout request path',
      source: 'codesphere', ms: 600, detail: '4 services');
  yield const StepStarted('metrics', 'Querying latency metrics', source: 'aws');
  await a.wait(120);
  yield const StepStarted('traces', 'Pulling distributed traces', source: 'gcp');
  await a.wait(120);
  yield const StepStarted('deploys', 'Checking recent deploys', source: 'codesphere');
  await a.wait(500);
  yield const StepCompleted('deploys', detail: '3 deploys / 24h');
  await a.wait(300);
  yield const StepCompleted('metrics', detail: '2,880 datapoints');
  await a.wait(400);
  yield const StepCompleted('traces', detail: '12,408 spans');
  yield* a.step('correlate', 'Correlating signals', ms: 700, detail: 'root cause found');

  yield a.ui({
    'type': 'brief',
    'severity': 'critical',
    'title': 'Checkout is slow in West Europe',
    'badge': 'Ongoing · 14 h',
    'items': [
      {'label': 'What', 'text': 'Checkout p95 is **1.92 s**, 2.4× over the 800 ms SLO.'},
      {'label': 'Impact', 'text': '18.4k sessions affected, conversion −0.4 pp, about **€6.3k/day** revenue at risk.'},
      {'label': 'Cause', 'text': 'Deploy **#482** moved payment-svc to us-east1. Every checkout now makes 3 transatlantic calls.'},
      {'label': 'Fix', 'text': 'Roll back payment-svc to europe-west3. About 5 min, no downtime.'},
    ],
  });
  await a.wait(300);
  yield* a.say('Here is the evidence:');
  await a.wait(150);
  yield a.ui({
    'type': 'line_chart',
    'title': 'Checkout latency',
    'subtitle': 'Last 24 hours · West Europe',
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
  await a.wait(400);
  yield a.ui(_topology);
  await a.wait(400);
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
  yield* a.say('How do you want to proceed?');
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'rollback', 'label': 'Roll back payment-svc to europe-west3', 'variant': 'primary', 'icon': 'rollback'},
      {'id': 'batch', 'label': 'Batch the 3 payment calls', 'variant': 'outline', 'icon': 'bolt'},
      {'id': 'ticket', 'label': 'Open incident', 'variant': 'ghost', 'icon': 'ticket'},
    ],
  });
  yield a.ui(followups());
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

  yield a.ui({
    'type': 'brief',
    'severity': 'success',
    'title': 'You can cut cloud spend by 21.6%',
    'badge': '€11.4k / month',
    'items': [
      {'label': 'What', 'text': 'November is forecast at **€52.9k**, 9.7% over the €48.2k budget.'},
      {'label': 'Cause', 'text': 'An idle GPU pool, an oversized database, cross-cloud egress and orphaned volumes.'},
      {'label': 'Fix', 'text': '4 changes across 3 clouds. The two biggest have no or low risk.'},
      {'label': 'Savings', 'text': '**€11.4k/month**, that is €137k per year.'},
    ],
  });
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

// ------------------------------------------------- start page entry points ----

Stream<AgentEvent> incidentSearch(MockAgent a) async* {
  yield* a.step('logs', 'Reading search-api logs', source: 'azure', ms: 700, detail: '41k lines');
  yield* a.step('deps', 'Checking dependencies', source: 'azure', ms: 600, detail: 'index healthy');
  yield* a.step('correlate', 'Correlating with traffic', ms: 500, detail: 'match found');
  yield a.ui({
    'type': 'brief',
    'severity': 'warning',
    'title': 'Search errors elevated',
    'badge': 'Ongoing · 47 min',
    'items': [
      {'label': 'What', 'text': 'search-api returns 5xx on **1.8%** of requests (normally 0.2%).'},
      {'label': 'Impact', 'text': 'About 1 in 55 searches fails. Checkout is not affected.'},
      {'label': 'Cause', 'text': 'The app service plan hit its **instance limit (4/4)** during the lunch traffic peak.'},
      {'label': 'Fix', 'text': 'Raise the autoscale limit to 8 instances. About +€140/month.'},
    ],
  });
  yield a.ui({
    'type': 'line_chart',
    'title': 'search-api 5xx rate',
    'subtitle': 'Last 2 hours',
    'source': 'Azure Monitor',
    'unit': '%',
    'labels': List.generate(16, (i) => '${10 + (i * 8) ~/ 60}:${((i * 8) % 60).toString().padLeft(2, '0')}'),
    'series': [
      {'name': '5xx rate', 'values': [0.2, 0.2, 0.3, 0.2, 0.2, 0.3, 0.2, 0.3, 0.4, 0.6, 0.9, 1.1, 1.4, 1.5, 1.7, 1.8]},
    ],
    'threshold': 1.0,
    'threshold_label': 'Alert 1%',
    'highlight_from': 8,
    'highlight_label': 'Instance limit reached',
    'highlight_severity': 'warning',
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'scale_search', 'label': 'Raise autoscale limit to 8', 'variant': 'primary', 'icon': 'bolt'},
      {'id': 'cancel', 'label': 'Ignore for now', 'variant': 'ghost', 'icon': 'close'},
    ],
  });
}

Stream<AgentEvent> scaleSearch(MockAgent a) async* {
  yield* a.step('scale', 'Updating autoscale rule on search-plan', source: 'azure', ms: 1200, detail: 'max 4 → 8');
  yield* a.step('verify', 'Waiting for new instances', source: 'azure', ms: 1200, detail: '6 running');
  yield a.ui({
    'type': 'finding',
    'severity': 'success',
    'title': 'Search is recovering',
    'body': '5xx rate dropped to **0.3%** with 6 instances running.',
  });
}

Stream<AgentEvent> incidentStorage(MockAgent a) async* {
  yield* a.step('metrics', 'Reading storage metrics for orders-db', source: 'azure', ms: 700, detail: '30 days');
  yield* a.step('tables', 'Finding the largest tables', source: 'azure', ms: 700, detail: '3 tables');
  yield a.ui({
    'type': 'brief',
    'severity': 'warning',
    'title': 'orders-db storage 86% full',
    'badge': 'Full in ~9 days',
    'items': [
      {'label': 'What', 'text': 'orders-db uses **430 of 500 GB** and grows ~7 GB per day.'},
      {'label': 'Impact', 'text': 'No impact yet. When the disk is full, new orders fail.'},
      {'label': 'Cause', 'text': 'The `audit_log` table (212 GB) has no retention policy.'},
      {'label': 'Fix', 'text': 'Archive audit entries older than 90 days to cold storage. Frees ~180 GB.'},
    ],
  });
  yield a.ui({
    'type': 'bar_chart',
    'title': 'Largest tables',
    'source': 'Azure SQL',
    'unit': 'GB',
    'bars': [
      {'label': 'audit_log', 'sublabel': 'no retention policy', 'value': 212, 'highlight': true},
      {'label': 'orders', 'sublabel': '14.2M rows', 'value': 128},
      {'label': 'order_items', 'sublabel': '41.8M rows', 'value': 71},
      {'label': 'other', 'sublabel': '38 tables', 'value': 19},
    ],
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'archive', 'label': 'Archive audit logs > 90 days', 'variant': 'primary', 'icon': 'export'},
      {'id': 'cancel', 'label': 'Remind me tomorrow', 'variant': 'ghost', 'icon': 'close'},
    ],
  });
}

Stream<AgentEvent> archive(MockAgent a) async* {
  yield* a.step('policy', 'Creating 90-day retention policy', source: 'azure', ms: 900, detail: 'audit_log');
  yield* a.step('move', 'Moving old entries to cold storage', source: 'azure', ms: 1400, detail: '181 GB');
  yield a.ui({
    'type': 'finding',
    'severity': 'success',
    'title': 'Freed 181 GB on orders-db',
    'body': 'Storage is at **50%**. At current growth that lasts about 5 months.',
  });
}

Stream<AgentEvent> suggestGpu(MockAgent a) async* {
  yield* a.step('usage', 'Reading GPU utilisation for gke-ml-pool', source: 'gcp', ms: 800, detail: '14 days');
  yield* a.step('jobs', 'Checking the training job schedule', source: 'gcp', ms: 600, detail: '2 jobs / week');
  yield a.ui({
    'type': 'brief',
    'severity': 'success',
    'title': 'Scale idle GPU pool to zero',
    'badge': '€4.1k / month',
    'items': [
      {'label': 'What', 'text': 'gke-ml-pool runs **4× A100** around the clock.'},
      {'label': 'Cause', 'text': 'It is idle **92%** of the time. Training only runs twice a week.'},
      {'label': 'Fix', 'text': 'Enable scale-to-zero. Nodes start automatically when a job is queued.'},
      {'label': 'Savings', 'text': '**€4,120/month** with no impact on production.'},
    ],
  });
  yield a.ui({
    'type': 'line_chart',
    'title': 'GPU utilisation',
    'subtitle': 'Last 14 days · gke-ml-pool',
    'source': 'Cloud Monitoring',
    'unit': '%',
    'labels': List.generate(14, (i) => 'Nov ${i + 1}'),
    'series': [
      {'name': 'GPU util', 'values': [0, 0, 0, 0, 0, 2, 71, 3, 1, 0, 68, 2, 0, 1]},
    ],
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'stop_gpus', 'label': 'Enable scale-to-zero', 'variant': 'primary', 'icon': 'stop'},
      {'id': 'ask_costs', 'label': 'Show all savings', 'variant': 'outline', 'icon': 'savings'},
    ],
  });
}

Stream<AgentEvent> suggestEgress(MockAgent a) async* {
  yield* a.step('flows', 'Analysing cross-cloud traffic', source: 'gcp', ms: 800, detail: '3.1 TB / month');
  yield a.ui({
    'type': 'brief',
    'severity': 'success',
    'title': 'Keep payment traffic in the EU',
    'badge': '€3.0k / month',
    'items': [
      {'label': 'What', 'text': 'payment-svc in us-east1 sends **3.1 TB/month** to orders-db in Azure westeurope.'},
      {'label': 'Cause', 'text': 'Deploy #482 moved payment-svc out of the EU. This is also why **checkout is slow**.'},
      {'label': 'Fix', 'text': 'Roll back payment-svc to europe-west3.'},
      {'label': 'Savings', 'text': '**€2,960/month** in egress, plus checkout back under SLO.'},
    ],
  });
  yield a.ui({
    'type': 'actions',
    'actions': [
      {'id': 'rollback', 'label': 'Plan the rollback', 'variant': 'primary', 'icon': 'rollback'},
      {'id': 'ask_checkout', 'label': 'Show checkout impact', 'variant': 'outline', 'icon': 'bolt'},
    ],
  });
}
