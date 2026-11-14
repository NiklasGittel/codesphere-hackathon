import 'dart:async';

import '../models/ui_block.dart';
import 'agent_service.dart';

part 'mock_scenarios.dart';

/// Scripted agent for the demo. All data is simulated.
///
/// Blocks are written as JSON on purpose: it is exactly the shape the real
/// LLM will produce through a `render_ui` function call.
class MockAgent implements AgentService {
  @override
  Stream<AgentEvent> send(String message, {String? actionId}) {
    if (actionId != null) return _action(actionId);
    final q = message.toLowerCase();
    bool has(List<String> words) => words.any(q.contains);
    if (has(['checkout', 'slow', 'latency', 'p95', 'performance'])) {
      return checkout(this);
    }
    if (has(['cost', 'spend', 'save', 'saving', 'bill', 'budget', 'cheap'])) {
      return costs(this);
    }
    if (has(['change', 'deploy', 'release', '24h', 'yesterday'])) {
      return changes(this);
    }
    return overview(this);
  }

  Stream<AgentEvent> _action(String id) {
    switch (id) {
      case 'ask_checkout':
        return checkout(this);
      case 'ask_costs':
        return costs(this);
      case 'rollback':
        return rollbackPlan(this);
      case 'confirm_rollback':
        return rollbackRun(this);
      case 'batch':
        return batch(this);
      case 'ticket':
        return ticket(this);
      case 'stop_gpus':
        return stopGpus(this);
      case 'rightsize':
        return rightsize(this);
      case 'cancel':
        return simple(
            'Okay, nothing was changed. Let me know if you want to look at other options.');
      default:
        return simple('Done.');
    }
  }

  // ------------------------------------------------------------ helpers ----

  Future<void> wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Stream<AgentEvent> step(String id, String label,
      {String? source, int ms = 700, String? detail}) async* {
    yield StepStarted(id, label, source: source);
    await wait(ms);
    yield StepCompleted(id, detail: detail);
  }

  Stream<AgentEvent> say(String text) async* {
    final words = text.split(' ');
    for (var i = 0; i < words.length; i++) {
      yield TextChunk(i == 0 ? words[i] : ' ${words[i]}', startsNew: i == 0);
      await wait(14);
    }
  }

  AgentEvent ui(Map<String, dynamic> json) =>
      BlockEmitted(UiBlock.fromJson(json));

  Stream<AgentEvent> simple(String text) async* {
    yield* step('think', 'Thinking', ms: 400);
    yield* say(text);
  }
}
