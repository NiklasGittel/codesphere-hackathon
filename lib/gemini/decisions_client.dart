import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_client.dart';

/// Gemini Decisions API (`gemini-decision-1`): closed-set decisions
/// (yes/no, choice, score) returned as calibrated probabilities instead of
/// generated text. Fast and cheap, which makes it a good fit for routing and
/// policy checks inside an agent loop.
class DecisionsClient {
  static const model =
      String.fromEnvironment('GEMINI_DECISION_MODEL', defaultValue: 'gemini-decision-1');

  static bool get configured => GeminiClient.configured;

  static final _endpoint =
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/decisions');

  /// Sends [input] with [questions] (key -> question object) and returns the
  /// `answers` map keyed like [questions].
  Future<Map<String, dynamic>> decide(String input, Map<String, Map<String, dynamic>> questions,
      {Duration timeout = const Duration(seconds: 6)}) async {
    final res = await http
        .post(
          _endpoint,
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': GeminiClient.apiKey},
          body: jsonEncode({'model': model, 'input': input, 'questions': questions}),
        )
        .timeout(timeout);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw GeminiException.fromError(res.statusCode, body['error']);
    return Map<String, dynamic>.from(body['answers'] as Map? ?? const {});
  }

  /// Question helpers matching the API's three types.
  static Map<String, dynamic> yesNo(String instructions, {String? yes, String? no}) => {
        'type': 'noul',
        'instructions': instructions,
        if (yes != null || no != null)
          'criteria': {
            if (yes != null) 'true_description': yes,
            if (no != null) 'false_description': no,
          },
      };

  static Map<String, dynamic> choice(String instructions, Map<String, String> options) =>
      {'type': 'choice', 'instructions': instructions, 'criteria': options};

  static Map<String, dynamic> score(String instructions, List<String> levelsLowFirst) =>
      {'type': 'score', 'instructions': instructions, 'criteria': levelsLowFirst};
}
