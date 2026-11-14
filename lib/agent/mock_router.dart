part of 'mock_agent.dart';

/// Every intent maps to a scripted scenario (see `MockAgent._action`).
/// Gemini picks one of these for free-form (typed or spoken) questions.
const intents = <String, String>{
  'incident_checkout': 'Why checkout or payment is slow, its root cause, or a general analysis of the checkout incident',
  'regions': 'Which regions, countries, locations or customer groups are affected; geographic breakdown',
  'trace': 'Show a single request or trace; where the time is spent inside one checkout request; spans, calls',
  'funnel': 'Impact on customers, conversion, orders, cart abandonment, sales or revenue right now',
  'timeline': 'What happened when; sequence of events; incident history; why nobody noticed or reacted',
  'error_budget': 'SLO, SLA, error budget, reliability, burn rate, availability targets',
  'black_friday': 'Future impact or projection if it is not fixed; Black Friday, Cyber Monday, upcoming peak traffic; forecast of losses',
  'rollback': 'How to fix it, roll back, remediation or mitigation plan, make checkout fast again',
  'changes': 'Recent deploys, releases or configuration changes in production',
  'costs': 'Cloud spend, costs, bill, savings opportunities, budget, making things cheaper',
  'suggest_gpu': 'GPU pool, idle GPUs, machine learning nodes',
  'rightsize': 'Oversized database, database instance size, rightsizing',
  'suggest_egress': 'Egress or network transfer costs between clouds',
  'incident_search': 'Search errors, search-api 5xx',
  'incident_storage': 'Database storage or disk running full',
  'overview': 'General status or health of production, service map, or anything else',
};

const intentLabels = <String, String>{
  'incident_checkout': 'checkout incident',
  'regions': 'regional breakdown',
  'trace': 'request trace',
  'funnel': 'conversion impact',
  'timeline': 'incident timeline',
  'error_budget': 'SLO & error budget',
  'black_friday': 'Black Friday projection',
  'rollback': 'remediation',
  'changes': 'recent changes',
  'costs': 'cost analysis',
  'suggest_gpu': 'GPU savings',
  'rightsize': 'rightsizing',
  'suggest_egress': 'egress costs',
  'incident_search': 'search errors',
  'incident_storage': 'storage',
  'overview': 'overview',
};

const _routingContext =
    'Context: the user operates an online shop on AWS, Google Cloud, Azure and codesphere. '
    'There is an ongoing incident: checkout is slow in West Europe (p95 1.92 s) since deploy #482 '
    'moved payment-svc from europe-west3 to us-east1. Short follow-up questions usually refer to this incident.';

/// Fallback when Gemini is not configured or fails.
String keywordIntent(String message) {
  final q = message.toLowerCase();
  bool has(List<String> words) => words.any(q.contains);
  if (has(['black friday', 'cyber monday', 'what if', "don't fix", 'dont fix', 'not fix', 'projection', 'future', 'next week'])) {
    return 'black_friday';
  }
  if (has(['error budget', 'burn', 'reliability', 'slo ', 'slo?', 'sla', 'availability'])) return 'error_budget';
  if (has(['timeline', 'happened', 'step by step', 'when did', 'sequence', 'history', 'noticed'])) return 'timeline';
  if (has(['trace', 'waterfall', 'span', 'single request', 'one request', 'time spent', 'where does the time'])) return 'trace';
  if (has(['conversion', 'funnel', 'customer', 'sales', 'abandon', 'revenue', 'orders', 'money we lose'])) return 'funnel';
  if (has(['region', 'countr', 'affected', 'heatmap', 'europe', 'where'])) return 'regions';
  if (has(['fix', 'roll back', 'rollback', 'resolve', 'mitigat'])) return 'rollback';
  if (has(['gpu'])) return 'suggest_gpu';
  if (has(['egress'])) return 'suggest_egress';
  if (has(['cost', 'spend', 'save', 'saving', 'bill', 'budget', 'cheap'])) return 'costs';
  if (has(['change', 'deploy', 'release', '24h', 'yesterday'])) return 'changes';
  if (has(['search'])) return 'incident_search';
  if (has(['storage', 'disk'])) return 'incident_storage';
  if (has(['checkout', 'slow', 'latency', 'p95', 'performance', 'why'])) return 'incident_checkout';
  return 'overview';
}
