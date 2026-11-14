import 'dart:convert';
import 'dart:typed_data';

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
  GeminiException(this.message);
  final String message;
  @override
  String toString() => 'Gemini error $message';
}
