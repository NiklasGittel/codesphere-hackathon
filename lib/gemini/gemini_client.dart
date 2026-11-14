import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Minimal Gemini REST client.
///
/// Configure at build time:
///   flutter run -d chrome --dart-define=GEMINI_API_KEY=... [--dart-define=GEMINI_MODEL=...]
class GeminiClient {
  static const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const model =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-flash-latest');

  static bool get configured => apiKey.isNotEmpty;

  static const _transcribePrompt =
      'Transcribe the spoken audio verbatim. The speaker is asking an AI assistant '
      'about their cloud infrastructure and business, so terms like checkout, latency, '
      'p95, SLO, error budget, AWS, Google Cloud, GCP, Azure, codesphere, payment-svc, '
      'rollback and Black Friday may appear. Reply with the transcription only: no quotes, '
      'no labels, no extra text. If there is no speech, reply with nothing.';

  Uri get _endpoint => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

  /// Speech to text with Gemini. [wav] is 16 kHz mono PCM WAV.
  Future<String> transcribe(Uint8List wav) async {
    final res = await http.post(
      _endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': _transcribePrompt},
              {
                'inline_data': {'mime_type': 'audio/wav', 'data': base64Encode(wav)}
              },
            ],
          }
        ],
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      final err = body['error'];
      final msg = err is Map ? err['message'] : null;
      throw GeminiException('${res.statusCode}: ${msg ?? res.reasonPhrase}');
    }
    final candidates = body['candidates'] as List? ?? const [];
    if (candidates.isEmpty) return '';
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ?? const [];
    final text = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text'] ?? '')
        .join()
        .trim();
    return text.replaceAll(RegExp(r'^["“]+|["”]+$'), '').trim();
  }

  /// One generateContent turn. Returns the model's content (role + parts),
  /// unmodified so thought signatures can be sent back in the history.
  Future<Map<String, dynamic>> generate({
    required List<Map<String, dynamic>> contents,
    String? system,
    List<Map<String, dynamic>>? functions,
  }) async {
    final payload = jsonEncode({
      if (system != null)
        'systemInstruction': {
          'parts': [
            {'text': system}
          ]
        },
      'contents': contents,
      if (functions != null)
        'tools': [
          {'functionDeclarations': functions}
        ],
    });

    GeminiException? last;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await _generateOnce(payload);
      } on GeminiException catch (e) {
        last = e;
        debugPrint('[gemini] attempt $attempt failed: ${e.message}');
        if (!e.retryable || attempt == 3) rethrow;
        final wait = e.retryAfter ?? Duration(milliseconds: 1200 * attempt);
        if (wait > const Duration(seconds: 12)) rethrow;
        await Future<void>.delayed(wait);
      }
    }
    throw last ?? GeminiException('unknown error');
  }

  Future<Map<String, dynamic>> _generateOnce(String payload) async {
    final http.Response res;
    try {
      res = await http.post(_endpoint, headers: {'Content-Type': 'application/json'}, body: payload);
    } catch (e) {
      throw GeminiException('network error: $e', retryable: true);
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw GeminiException('HTTP ${res.statusCode}: unreadable response', retryable: res.statusCode >= 500);
    }
    if (res.statusCode != 200) throw GeminiException.fromError(res.statusCode, body['error']);

    final candidates = body['candidates'] as List? ?? const [];
    if (candidates.isEmpty) {
      throw GeminiException('blocked or empty answer (${body['promptFeedback'] ?? 'no candidates'})', retryable: true);
    }
    final candidate = candidates.first as Map<String, dynamic>;
    final content = candidate['content'];
    if (content is! Map || content['parts'] is! List || (content['parts'] as List).isEmpty) {
      // e.g. MALFORMED_FUNCTION_CALL: usually works on a retry.
      throw GeminiException('empty answer (${candidate['finishReason']})', retryable: true);
    }
    return {...Map<String, dynamic>.from(content), 'role': 'model'};
  }

  /// Picks exactly one of [options] (id -> description) for [question].
  Future<String?> classify(String question, Map<String, String> options,
      {String? context}) async {
    if (!configured) return null;
    final list = options.entries.map((e) => '- ${e.key}: ${e.value}').join('\n');
    final prompt = 'You route user questions for Stratus, an AI assistant for cloud infrastructure.\n'
        '${context ?? ''}\n\n'
        'Pick the single intent that best matches the question.\n\nIntents:\n$list\n\n'
        'Question: "$question"';
    final res = await http.post(
      _endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ],
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'intent': {'type': 'STRING', 'enum': options.keys.toList()},
            },
            'required': ['intent'],
          },
        },
      }),
    );
    if (res.statusCode != 200) return null;
    final text = _text(jsonDecode(res.body) as Map<String, dynamic>);
    try {
      final intent = (jsonDecode(text) as Map)['intent'] as String?;
      return options.containsKey(intent) ? intent : null;
    } catch (_) {
      return null;
    }
  }

  static String _text(Map<String, dynamic> body) {
    final candidates = body['candidates'] as List? ?? const [];
    if (candidates.isEmpty) return '';
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ?? const [];
    return parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text'] ?? '')
        .join()
        .trim();
  }
}

class GeminiException implements Exception {
  GeminiException(this.message, {this.retryable = false, this.retryAfter});

  factory GeminiException.fromError(int status, dynamic error) {
    final msg = error is Map ? '${error['message'] ?? ''}' : '';
    Duration? retryAfter;
    if (error is Map && error['details'] is List) {
      for (final d in error['details'] as List) {
        final delay = d is Map ? d['retryDelay'] : null;
        final secs = delay is String ? double.tryParse(delay.replaceAll('s', '')) : null;
        if (secs != null) retryAfter = Duration(milliseconds: (secs * 1000).round());
      }
    }
    final friendly = switch (status) {
      400 when msg.toLowerCase().contains('api key') => 'API key is invalid. Check GEMINI_API_KEY.',
      401 || 403 => 'API key is not allowed to use this model ($msg)',
      404 => 'Model "${GeminiClient.model}" not found. Set --dart-define=GEMINI_MODEL=<model id>.',
      429 => 'Rate limit reached${retryAfter == null ? '' : ', retry in ${retryAfter.inSeconds}s'}. Free-tier keys allow only a few requests per minute.',
      >= 500 => 'Gemini is overloaded or unavailable ($status).',
      _ => msg,
    };
    return GeminiException('$status: $friendly',
        retryable: status == 429 || status >= 500, retryAfter: retryAfter);
  }

  final String message;
  final bool retryable;
  final Duration? retryAfter;

  @override
  String toString() => 'Gemini error $message';
}
