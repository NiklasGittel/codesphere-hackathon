import 'dart:async';
import 'dart:math' as math;

import '../gemini/gemini_client.dart';
import '../models/ui_block.dart';
import 'agent_service.dart';

part 'mock_insights.dart';
part 'mock_router.dart';
part 'mock_scenarios.dart';

/// Scripted agent for the demo. All data is simulated.
///
/// Blocks are written as JSON on purpose: it is exactly the shape the real
/// LLM will produce through a `render_ui` function call.
class MockAgent implements AgentService {
  final _gemini = GeminiClient();

  @override
  void reset() {}

  @override
  Stream<AgentEvent> send(String message, {String? actionId}) async* {
    if (actionId != null) {
      yield* _action(actionId);
      return;
    }
    final useGemini = GeminiClient.configured;
    yield StepStarted('route', 'Understanding the question', source: useGemini ? 'gemini' : null);
    String? intent;
    if (useGemini) {
      try {
        intent = await _gemini
            .classify(message, intents, context: _routingContext)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        intent = null;
      }
    }
    intent ??= keywordIntent(message);
    yield StepCompleted('route', detail: intentLabels[intent] ?? intent);
    yield* _action(intent);
  }

  Stream<AgentEvent> _action(String id) {
    switch (id) {
      case 'regions':
        return regions(this);
      case 'trace':
        return trace(this);
      case 'funnel':
        return funnel(this);
      case 'timeline':
        return timeline(this);
      case 'error_budget':
        return errorBudget(this);
      case 'black_friday':
        return blackFriday(this);
      case 'changes':
        return changes(this);
      case 'costs':
        return costs(this);
      case 'overview':
        return overview(this);
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
      case 'nav_services':
        return overview(this);
      case 'nav_changes':
        return changes(this);
      case 'nav_costs':
        return costs(this);
      case 'incident_checkout':
        return checkout(this);
      case 'incident_search':
        return incidentSearch(this);
      case 'scale_search':
        return scaleSearch(this);
      case 'incident_storage':
        return incidentStorage(this);
      case 'archive':
        return archive(this);
      case 'suggest_savings':
        return costs(this);
      case 'suggest_gpu':
        return suggestGpu(this);
      case 'suggest_egress':
        return suggestEgress(this);
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
