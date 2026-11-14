import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../gemini/gemini_client.dart';
import '../../models/ui_block.dart';
import '../agent_service.dart';
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

  final InfraWorld world = InfraWorld();
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
                system: systemPrompt(DateTime.now()),
                functions: functionDeclarations,
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
      default:
        final stepId = 'tool${_stepSeq++}';
        yield StepStarted(stepId, toolLabel(name, args), source: toolSource(name, args));
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final result = world.call(name, args);
        _data.addAll(result.blocks);
        response.addAll(result.toResponse());
        yield StepCompleted(stepId, detail: result.detail);
    }
  }

  Stream<AgentEvent> _type(String text) async* {
    final words = text.split(' ');
    for (var i = 0; i < words.length; i++) {
      yield TextChunk(i == 0 ? words[i] : ' ${words[i]}', startsNew: i == 0);
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }
}
