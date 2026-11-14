/// Builds UI blocks from the backend's /api/live/payment-svc payload.
/// Used for the first render (tool result) and for live refreshes.
library;

List<Map> _maps(dynamic v) => (v as List? ?? const []).whereType<Map>().toList();

Map<String, dynamic> _env(Map r) => Map<String, dynamic>.from(r['env'] as Map? ?? const {});

Map<String, dynamic> liveLatencyBlock(Map d) {
  final probe = Map<String, dynamic>.from(d['probe'] as Map? ?? const {});
  final series = _maps(probe['series']);
  return {
    'type': 'line_chart',
    'live': 'latency',
    'title': 'payment-svc latency',
    'subtitle': 'Live probe every 2 s · Google Cloud Run · last 5 min',
    'source': 'Live · Cloud Run',
    'unit': 'ms',
    'labels': [for (final b in series) '${b['t']}'],
    'series': [
      {'name': 'p95', 'values': [for (final b in series) b['p95_ms'] ?? 0]},
    ],
    'threshold': 300,
    'threshold_label': 'Target 300 ms',
  };
}

Map<String, dynamic> liveStatusBlock(Map d) {
  final probe = Map<String, dynamic>.from(d['probe'] as Map? ?? const {});
  final p95 = probe['p95_ms'];
  final err = probe['error_rate_pct'];
  return {
    'type': 'stats',
    'live': 'status',
    'items': [
      {'label': 'p95 latency · live', 'value': '${p95 ?? '–'} ms', 'good': p95 is num ? p95 < 300 : null},
      {'label': 'Error rate · live', 'value': '${err ?? '–'}%', 'good': err is num ? err < 1 : null},
      for (final t in _maps(d['traffic']))
        {'label': 'Traffic', 'value': '${t['percent']}%', 'delta': '${t['revision']}'},
    ],
  };
}

Map<String, dynamic> liveRevisionsBlock(Map d) {
  final revisions = _maps(d['revisions']);
  final traffic = _maps(d['traffic']);
  String trafficOf(String rev) {
    final t = traffic.where((t) => t['revision'] == rev).toList();
    return t.isEmpty ? '0%' : '${t.first['percent']}%';
  }

  return {
    'type': 'table',
    'live': 'revisions',
    'title': 'payment-svc revisions',
    'subtitle': 'Google Cloud Run · ${d['region']} · live',
    'columns': ['Revision', 'Release', 'Injected delay', 'Error rate', 'Traffic'],
    'rows': [
      for (final r in revisions)
        [
          '${r['revision']}',
          '${_env(r)['RELEASE'] ?? '–'}',
          '${_env(r)['FAULT_DELAY_MS'] ?? '0'} ms',
          '${_env(r)['FAULT_ERROR_RATE'] ?? '0'}',
          trafficOf('${r['revision']}'),
        ]
    ],
    'highlight_rows': [
      for (var i = 0; i < revisions.length; i++)
        if ((double.tryParse('${_env(revisions[i])['FAULT_DELAY_MS'] ?? 0}') ?? 0) > 0) i
    ],
  };
}

/// Fresh JSON for a live block of [kind], or null if unknown.
Map<String, dynamic>? liveBlockJson(String kind, Map d) => switch (kind) {
      'latency' => liveLatencyBlock(d),
      'status' => liveStatusBlock(d),
      'revisions' => liveRevisionsBlock(d),
      _ => null,
    };
