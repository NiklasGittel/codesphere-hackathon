import '../models/ui_block.dart';

/// Static (simulated) data for the start page.
class Incident {
  const Incident({
    required this.id,
    required this.title,
    required this.summary,
    required this.severity,
    required this.since,
    required this.providers,
    required this.impact,
    required this.impactLabel,
    required this.trend,
  });
  final String id;
  final String title;
  final String summary;
  final Severity severity;
  final String since;
  final List<String> providers;
  final String impact;
  final String impactLabel;
  final List<double> trend;
}

class Suggestion {
  const Suggestion({
    required this.id,
    required this.title,
    required this.summary,
    required this.savings,
    required this.provider,
    required this.tag,
  });
  final String id;
  final String title;
  final String summary;
  final String savings;
  final String provider;
  final String tag;
}

const incidents = [
  Incident(
    id: 'incident_checkout',
    title: 'Checkout is slow in West Europe',
    summary: 'p95 latency 1.92 s, SLO is 800 ms · 18.4k sessions affected',
    severity: Severity.critical,
    since: '14 h',
    providers: ['aws', 'gcp', 'azure'],
    impact: '€6.3k',
    impactLabel: 'revenue at risk / day',
    trend: [402, 388, 415, 431, 398, 376, 362, 391, 420, 1840, 1910, 1785, 1702, 1655, 1690, 1720, 1810, 1880, 1965, 2010, 1940, 1895, 1930, 1920],
  ),
  Incident(
    id: 'incident_search',
    title: 'Search errors elevated',
    summary: '5xx rate 1.8% on search-api (normally 0.2%)',
    severity: Severity.warning,
    since: '47 min',
    providers: ['azure'],
    impact: '1.8%',
    impactLabel: 'error rate',
    trend: [0.2, 0.2, 0.3, 0.2, 0.2, 0.3, 0.2, 0.3, 0.4, 0.6, 0.9, 1.1, 1.4, 1.5, 1.7, 1.8],
  ),
  Incident(
    id: 'incident_storage',
    title: 'orders-db storage 86% full',
    summary: 'Projected to run out of disk in 9 days',
    severity: Severity.warning,
    since: '2 d',
    providers: ['azure'],
    impact: '9 days',
    impactLabel: 'until full',
    trend: [61, 63, 64, 66, 68, 69, 71, 73, 75, 77, 79, 81, 83, 84, 86],
  ),
];

const totalSuggestion = (
  id: 'suggest_savings',
  percent: '21.6%',
  savings: '€11.4k',
  forecast: 52.9,
  saving: 11.4,
  budget: 48.2,
);

const suggestions = [
  Suggestion(
    id: 'suggest_gpu',
    title: 'Scale idle GPU pool to zero',
    summary: 'gke-ml-pool is idle 92% of the time',
    savings: '€4.1k',
    provider: 'gcp',
    tag: 'No risk',
  ),
  Suggestion(
    id: 'rightsize',
    title: 'Rightsize orders-db',
    summary: 'Average CPU 6% on db.r6g.4xlarge',
    savings: '€3.2k',
    provider: 'aws',
    tag: 'Low risk',
  ),
  Suggestion(
    id: 'suggest_egress',
    title: 'Keep payment traffic in the EU',
    summary: 'Cross-cloud egress from GCP to Azure',
    savings: '€3.0k',
    provider: 'gcp',
    tag: 'Fixes incident',
  ),
];
