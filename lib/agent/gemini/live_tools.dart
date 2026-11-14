import '../../live/live_blocks.dart';
import '../../live/live_client.dart';
import 'world.dart';

/// Turns the backend's live Cloud Run data into a tool result
/// (summary for Gemini + ready-made UI blocks).
class LiveTools {
  final LiveClient _client = LiveClient();
  Map<String, dynamic>? _last;

  static const toolName = 'get_live_payment_svc';

  static Map<String, dynamic> get declaration => {
        'name': toolName,
        'description':
            'LIVE data from Google Cloud Run for payment-svc, measured right now: traffic split, revisions with '
                'their environment config (diff shows what deploy #482 changed), and real p95 latency and error rate '
                'from a live probe. data_ids: live_latency (line chart), live_status (stats), live_revisions (table).',
      };

  Future<ToolResult> fetch() async {
    final d = await _client.paymentSvc();
    _last = d;
    final probe = Map<String, dynamic>.from(d['probe'] as Map? ?? const {});
    final traffic = (d['traffic'] as List? ?? const []).whereType<Map>().toList();
    final revisions = (d['revisions'] as List? ?? const []).whereType<Map>().toList();

    Map<String, dynamic> envOf(Map r) => Map<String, dynamic>.from(r['env'] as Map? ?? const {});
    final diffs = <String, dynamic>{};
    if (revisions.length >= 2) {
      final newer = envOf(revisions[0]), older = envOf(revisions[1]);
      for (final k in {...newer.keys, ...older.keys}) {
        if (newer[k] != older[k]) diffs[k] = {'${revisions[1]['revision']}': older[k], '${revisions[0]['revision']}': newer[k]};
      }
    }
    final p95 = probe['p95_ms'];
    final err = probe['error_rate_pct'];

    return ToolResult({
      'source': 'LIVE Google Cloud Run (${d['region']})',
      'service': d['service'],
      'traffic': traffic,
      'revisions': [
        for (final r in revisions) {'revision': r['revision'], 'created': r['created'], 'env': envOf(r)}
      ],
      'env_changes_newest_vs_previous_revision': diffs,
      'live_probe_last_30s': {
        'p50_ms': probe['p50_ms'],
        'p95_ms': p95,
        'error_rate_pct': err,
        'requests': probe['requests'],
        'served_by_revision': probe['served_by_revision'],
      },
      'rollback_target_hint': healthyRevision,
    }, detail: 'live · p95 ${p95 ?? '?'} ms · ${err ?? '?'}% errors', blocks: {
      'live_latency': liveLatencyBlock(d),
      'live_status': liveStatusBlock(d),
      'live_revisions': liveRevisionsBlock(d),
    });
  }

  /// Newest revision without injected faults (the rollback target).
  String get healthyRevision {
    final revs = (_last?['revisions'] as List? ?? const []).whereType<Map>();
    for (final r in revs) {
      final env = Map<String, dynamic>.from(r['env'] as Map? ?? const {});
      final delay = double.tryParse('${env['FAULT_DELAY_MS'] ?? 0}') ?? 0;
      final errors = double.tryParse('${env['FAULT_ERROR_RATE'] ?? 0}') ?? 0;
      if (delay == 0 && errors == 0) return '${r['revision']}';
    }
    return 'payment-svc-v481';
  }

  Future<ToolResult> rollback() async {
    if (_last == null) {
      try {
        await fetch();
      } catch (_) {}
    }
    final target = healthyRevision;
    final r = await _client.rollback(target);
    return ToolResult({
      'status': r['status'],
      'live': true,
      'traffic_now_routed_to': target,
      'operation': r['operation'],
      'next': 'Cloud Run shifts traffic within ~10-30 s. Call get_live_payment_svc again to show the live latency dropping.',
    }, detail: 'Cloud Run traffic → $target');
  }
}
