import 'package:flutter/foundation.dart';

import '../agent/agent_service.dart';
import '../models/chat_message.dart';
import '../models/ui_block.dart';

class ChatController extends ChangeNotifier {
  ChatController(this.agent);

  final AgentService agent;
  final List<ChatMessage> messages = [];

  bool get busy => _busy;
  bool _busy = false;
  bool _cancelled = false;

  Future<void> send(String text, {String? actionId}) async {
    final trimmed = text.trim();
    if (_busy || trimmed.isEmpty) return;

    messages.add(ChatMessage(role: Role.user, isAction: actionId != null)
      ..parts.add(TextPart(trimmed)));
    final reply = ChatMessage(role: Role.assistant);
    messages.add(reply);
    _busy = true;
    _cancelled = false;
    notifyListeners();

    try {
      await for (final event in agent.send(trimmed, actionId: actionId)) {
        if (_cancelled) break;
        _apply(reply, event);
        notifyListeners();
      }
    } catch (e) {
      reply.parts.add(BlockPart(FindingBlock(
          title: 'Something went wrong',
          body: '$e',
          severity: Severity.critical)));
    }

    if (_cancelled) {
      for (final s in reply.steps) {
        if (s.status == StepStatus.running) s.status = StepStatus.failed;
      }
      reply.parts.add(TextPart('Stopped.'));
    }
    reply.done = true;
    reply.finishedAt = DateTime.now();
    _busy = false;
    notifyListeners();
  }

  void runAction(ActionsBlock block, ActionItem action) {
    if (_busy || block.chosenId != null) return;
    block.chosenId = action.id;
    send(action.label, actionId: action.id);
  }

  void stop() {
    if (_busy) _cancelled = true;
  }

  void reset() {
    if (_busy) _cancelled = true;
    messages.clear();
    notifyListeners();
  }

  void _apply(ChatMessage reply, AgentEvent event) {
    switch (event) {
      case StepStarted e:
        reply.steps.add(AgentStep(id: e.id, label: e.label, source: e.source));
      case StepCompleted e:
        for (final s in reply.steps) {
          if (s.id == e.id) {
            s.status = StepStatus.done;
            s.detail = e.detail;
            s.took = DateTime.now().difference(s.startedAt);
          }
        }
      case TextChunk e:
        final last = reply.parts.isEmpty ? null : reply.parts.last;
        if (!e.startsNew && last is TextPart) {
          last.text += e.text;
        } else {
          reply.parts.add(TextPart(e.text));
        }
      case BlockEmitted e:
        reply.parts.add(BlockPart(e.block));
    }
  }
}
