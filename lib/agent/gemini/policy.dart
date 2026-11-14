import '../../gemini/decisions_client.dart';

/// Result of the human-in-the-loop policy check before a production change.
class PolicyVerdict {
  const PolicyVerdict({required this.allowed, required this.confirmed, this.risk, this.error});
  final bool allowed;

  /// Probability that the user explicitly confirmed the action.
  final double confirmed;

  /// low | medium | high (null if unknown).
  final String? risk;
  final String? error;

  String get detail => error != null
      ? 'check unavailable'
      : 'confirmed ${(confirmed * 100).round()}%${risk == null ? '' : ' · risk $risk'}';
}

/// Uses the Gemini Decisions API to verify that a production change was
/// explicitly confirmed by the user, and to rate its risk.
class ActionPolicy {
  ActionPolicy([DecisionsClient? client]) : _client = client ?? DecisionsClient();
  final DecisionsClient _client;

  static const _riskLevels = [
    'low: reversible, no customer-facing downtime expected',
    'medium: customer impact possible but limited or brief',
    'high: likely customer-facing downtime or data loss',
  ];

  Future<PolicyVerdict> check({required String action, required String lastUserMessage}) async {
    try {
      final answers = await _client.decide(
        'Proposed production change: $action\n'
        'Latest message from the user: "$lastUserMessage"',
        {
          'confirmed': DecisionsClient.yesNo(
            'Did the user explicitly confirm that this exact production change should be executed now?',
            yes: 'The user clicked a confirm button or clearly approved executing this change now.',
            no: 'The user only asked a question, asked for a plan, or approved something else.',
          ),
          'risk': DecisionsClient.score(
            'How risky is this production change for an online shop?',
            _riskLevels,
          ),
        },
      );
      final confirmed = ((answers['confirmed'] as Map?)?['noul'] as num?)?.toDouble() ?? 0;
      final score = ((answers['risk'] as Map?)?['score'] as num?)?.toDouble();
      final risk = score == null ? null : ['low', 'medium', 'high'][score.round().clamp(0, 2).toInt()];
      return PolicyVerdict(allowed: confirmed >= 0.5, confirmed: confirmed, risk: risk);
    } catch (e) {
      // Fail safe but usable: fall back to the button protocol.
      final viaButton = lastUserMessage.contains('action id: confirm');
      return PolicyVerdict(allowed: viaButton, confirmed: viaButton ? 1 : 0, error: '$e');
    }
  }
}
