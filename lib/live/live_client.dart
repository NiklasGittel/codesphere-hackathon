import 'dart:convert';

import 'package:http/http.dart' as http;

/// Talks to the backend's live endpoints (payment-svc on Google Cloud Run).
/// Configure with --dart-define=STRATUS_BACKEND=http://localhost:8080
class LiveClient {
  static const baseUrl = String.fromEnvironment('STRATUS_BACKEND');
  static bool get configured => baseUrl.isNotEmpty;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> paymentSvc({bool fresh = false}) async {
    final res = await http
        .get(_u('/api/live/payment-svc${fresh ? '?fresh=true' : ''}'))
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception('live backend ${res.statusCode}: ${body is Map ? body['detail'] : body}');
    return Map<String, dynamic>.from(body as Map);
  }

  Future<Map<String, dynamic>> rollback(String revision) async {
    final res = await http
        .post(_u('/api/live/payment-svc/rollback'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'revision': revision, 'approved': true}))
        .timeout(const Duration(seconds: 40));
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) throw Exception('live rollback ${res.statusCode}: ${body is Map ? body['detail'] : body}');
    return Map<String, dynamic>.from(body as Map);
  }

  /// Rehearsal reset: bad revision gets all traffic again, latency history
  /// cleared. Also resets the backend's own shop simulation (best effort).
  Future<void> reset() async {
    final res = await http.post(_u('/api/live/payment-svc/reset')).timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception('live reset ${res.statusCode}: ${body is Map ? body['detail'] : body}');
    }
    try {
      await http.post(_u('/api/reset')).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
