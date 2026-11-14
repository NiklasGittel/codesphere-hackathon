import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../gemini/gemini_client.dart';
import '../../models/ui_block.dart';
import '../agent_service.dart';
import '../../live/live_client.dart';
import 'live_tools.dart';
import 'policy.dart';
import 'prompt.dart';
import 'world.dart';

/// Real agent: Gemini plans the investigation, calls data tools on the
/// simulated estate ([InfraWorld]) and builds the answer from UI components
/// via `show_data` / `render_ui` function calls.
class GeminiAgent implements AgentService {
  GeminiAgent({GeminiClient? client, this.fallback}) : _client = client ?? GeminiClient();

  final GeminiClient _client;

  /// Used when Gemini is unreachable on the first turn (demo safety net).
  final AgentService? fallback;

  InfraWorld world = InfraWorld();
  final ActionPolicy _policy = ActionPolicy();
  final LiveTools _live = LiveTools();
  String _lastUserText = '';
  /// One Gemini history per conversation.
  final Map<String, List<Map<String, dynamic>>> _sessions = {};
  String _session = 'default';
  List<Map<String, dynamic>> get _history => _sessions.putIfAbsent(_session, () => []);
  final Map<String, Map<String, dynamic>> _data = {};
  int _stepSeq = 0;

  static const maxTurns = 10;
  static const _componentTypes = {
    'stats', 'line_chart', 'bar_chart', 'topology', 'finding', 'table', 'actions',
    'brief', 'heatmap', 'waterfall', 'funnel', 'timeline', 'gauges', 'followups',
  };

  @override
  void useSession(String id) {
    _session = id;
    fallback?.useSession(id);
  }

  @override
  void reset() {
    _sessions.clear();
    _data.clear();
    world = InfraWorld(); // back to the open incident
    fallback?.reset();
  }

  String _userText(String message, String? actionId) {
    if (actionId == null) return message;
    const opened = ['incident_', 'suggest_', 'nav_'];
    if (opened.any(actionId.startsWith) || (actionId == 'rightsize' && _history.isEmpty)) {
      return 'User opened "$message" (id: $actionId) from the overview. Investigate it and present the result.';
    }
    return 'User clicked the button "$message" (action id: $actionId).';
  }

  @override
  Stream<AgentEvent> send(String message, {String? actionId}) async* {
    // Everything this message adds to the history is rolled back unless the
    // turn finishes cleanly. Otherwise a failed or stopped answer would leave
    // a function call without a response and break every later request.
    final history = _history;
    final snapshot = history.length;
    _lastUserText = _userText(message, actionId);
    var clean = false;
    history.add({
      'role': 'user',
      'parts': [
        {'text': _userText(message, actionId)}
      ],
    });

    try {
      for (var turn = 0; turn < maxTurns; turn++) {
        final thinkId = 'think${_stepSeq++}';
        yield StepStarted(thinkId, turn == 0 ? 'Planning the investigation' : 'Analysing results',
            source: 'gemini');

        Map<String, dynamic> content;
        try {
          content = await _client
              .generate(
                contents: history,
                system: systemPrompt(DateTime.now(), live: LiveClient.configured),
                functions: [
                  ...functionDeclarations,
                  if (LiveClient.configured) LiveTools.declaration,
                ],
              )
              .timeout(const Duration(seconds: 60));
        } catch (e) {
          yield StepCompleted(thinkId, detail: 'failed');
          final reason = e is GeminiException ? e.message : '$e';
          debugPrint('[gemini-agent] $reason');
          history.length = snapshot;
          clean = true;
          if (turn == 0 && fallback != null) {
            yield TextChunk('Gemini is unavailable (**$reason**). Using the offline playbook instead.',
                startsNew: true);
            yield* fallback!.send(message, actionId: actionId);
          } else {
            yield TextChunk('Gemini stopped responding (**$reason**). Please ask again in a moment.',
                startsNew: true);
          }
          return;
        }
        history.add(content);

        final parts = (content['parts'] as List).whereType<Map>().toList();
        final calls = parts.where((p) => p['functionCall'] is Map).toList();
        yield StepCompleted(thinkId,
            detail: calls.isEmpty ? 'answer ready' : '${calls.length} call${calls.length == 1 ? '' : 's'}');

        for (final p in parts) {
          final text = p['text'];
          if (text is String && p['thought'] != true && text.trim().isNotEmpty) {
            yield* _type(text.trim());
          }
        }
        if (calls.isEmpty) {
          clean = true;
          return;
        }

        final responses = <Map<String, dynamic>>[];
        for (final p in calls) {
          final call = Map<String, dynamic>.from(p['functionCall'] as Map);
          final name = '${call['name']}';
          final args = Map<String, dynamic>.from((call['args'] as Map?) ?? const {});
          final response = <String, dynamic>{};
          try {
            await for (final event in _runTool(name, args, response)) {
              yield event;
            }
          } catch (e) {
            response
              ..clear()
              ..['error'] = 'tool failed: $e';
          }
          responses.add({
            'functionResponse': {
              if (call['id'] != null) 'id': call['id'],
              'name': name,
              'response': response,
            },
          });
        }
        history.add({'role': 'user', 'parts': responses});
      }
      // Too many turns: drop this exchange so the history stays valid.
      history.length = snapshot;
      clean = true;
      yield const TextChunk('I stopped here to keep the answer short. Ask me to continue.', startsNew: true);
    } finally {
      if (!clean && history.length > snapshot) history.length = snapshot;
    }
  }

  /// Executes one function call; writes the result into [response].
  Stream<AgentEvent> _runTool(String name, Map<String, dynamic> args, Map<String, dynamic> response) async* {
    switch (name) {
      case 'show_data':
        final dataId = '${args['data_id']}';
        final stored = _data[dataId];
        if (stored == null) {
          response['error'] = 'unknown data_id "$dataId". Available: ${_data.keys.join(', ')}. Call a data tool first.';
          return;
        }
        final block = Map<String, dynamic>.from(stored);
        if (args['title'] is String && (args['title'] as String).isNotEmpty) block['title'] = args['title'];
        if (args['subtitle'] is String && (args['subtitle'] as String).isNotEmpty) block['subtitle'] = args['subtitle'];
        yield BlockEmitted(UiBlock.fromJson(block));
        response['ok'] = true;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      case 'render_ui':
        final raw = args['component_json'] ?? args['component'];
        Map<String, dynamic>? component;
        try {
          final decoded = raw is String ? jsonDecode(raw) : raw;
          if (decoded is Map) component = Map<String, dynamic>.from(decoded);
        } catch (e) {
          response['error'] = 'component_json is not valid JSON: $e';
          return;
        }
        if (component == null || !_componentTypes.contains(component['type'])) {
          response['error'] = 'component needs a "type" out of ${_componentTypes.join(', ')}';
          return;
        }
        yield BlockEmitted(UiBlock.fromJson(component));
        response['ok'] = true;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      case 'execute_action':
        // Human-in-the-loop guard via the Gemini Decisions API.
        final action = '${args['action']}';
        final checkId = 'policy${_stepSeq++}';
        yield StepStarted(checkId, 'Policy check: was this change approved?', source: 'gemini-decisions');
        final verdict = await _policy.check(action: action, lastUserMessage: _lastUserText);
        yield StepCompleted(checkId, detail: verdict.detail);
        final policy = {'confirmed_probability': verdict.confirmed, 'risk': verdict.risk};
        if (!verdict.allowed) {
          response['error'] = 'Blocked by policy: the user has not explicitly confirmed "$action". '
              'Show the plan with a Confirm button (id "confirm:$action") and wait for the click.';
          response['policy'] = policy;
          return;
        }
        if (action == 'rollback_payment_svc' && LiveClient.configured) {
          yield* _liveRollback(response);
          world.call(name, args); // keep the simulated estate consistent
        } else {
          yield* _dataTool(name, args, response);
        }
        response['policy'] = policy;
      case LiveTools.toolName:
        final liveId = 'live${_stepSeq++}';
        yield StepStarted(liveId, 'Reading payment-svc live from Cloud Run', source: 'gcp');
        try {
          final result = await _live.fetch();
          _data.addAll(result.blocks);
          response.addAll(result.toResponse());
          yield StepCompleted(liveId, detail: result.detail);
        } catch (e) {
          response['error'] = 'live data unavailable: $e';
          yield StepCompleted(liveId, detail: 'unavailable');
        }
      default:
        yield* _dataTool(name, args, response);
    }
  }

  Stream<AgentEvent> _liveRollback(Map<String, dynamic> response) async* {
    final stepId = 'live${_stepSeq++}';
    yield StepStarted(stepId, 'Shifting Cloud Run traffic to the healthy revision', source: 'gcp');
    try {
      final result = await _live.rollback();
      response.addAll(result.toResponse());
      yield StepCompleted(stepId, detail: result.detail);
    } catch (e) {
      response['error'] = 'live rollback failed: $e';
      yield StepCompleted(stepId, detail: 'failed');
    }
  }

  Stream<AgentEvent> _dataTool(String name, Map<String, dynamic> args, Map<String, dynamic> response) async* {
    final stepId = 'tool${_stepSeq++}';
    yield StepStarted(stepId, toolLabel(name, args), source: toolSource(name, args));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final result = world.call(name, args);
    _data.addAll(result.blocks);
    response.addAll(result.toResponse());
    yield StepCompleted(stepId, detail: result.detail);
  }

  Stream<AgentEvent> _type(String text) async* {
    final words = text.split(' ');
    for (var i = 0; i < words.length; i++) {
      yield TextChunk(i == 0 ? words[i] : ' ${words[i]}', startsNew: i == 0);
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }
}
