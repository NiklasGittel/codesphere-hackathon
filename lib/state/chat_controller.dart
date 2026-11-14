import 'package:flutter/foundation.dart';

import '../agent/agent_service.dart';
import '../models/chat_message.dart';
import '../models/ui_block.dart';

/// One investigation (chat) with its own messages and agent history.
class Conversation {
  Conversation({required this.id, required this.title}) : updatedAt = DateTime.now();
  final String id;
  final String title;
  final List<ChatMessage> messages = [];
  DateTime updatedAt;
}

/// Keeps all conversations in memory. Opening a topic again shows the
/// existing chat instead of re-running the investigation.
class ChatController extends ChangeNotifier {
  ChatController(this.agent);

  final AgentService agent;
  final Map<String, Conversation> _conversations = {};
  Conversation? _current;
  int _seq = 0;

  /// Messages of the open conversation (empty on the overview page).
  List<ChatMessage> get messages => _current?.messages ?? const [];
  Conversation? get current => _current;

  /// Most recently active first.
  List<Conversation> get conversations =>
      _conversations.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  bool get busy => _running != null;

  /// Conversation that is currently being answered (may not be the open one).
  String? get runningId => _running?.id;
  Conversation? _running;
  bool _cancelled = false;

  bool hasConversation(String id) => _conversations.containsKey(id);

  /// Opens the conversation [id]. If it does not exist yet it is created and
  /// [prompt] is sent (with [actionId], e.g. for start-page cards).
  void open(String id, String title, {String? prompt, String? actionId}) {
    final existing = _conversations[id];
    if (existing != null) {
      _current = existing;
      notifyListeners();
      return;
    }
    if (busy) return;
    final conv = Conversation(id: id, title: title);
    _conversations[id] = conv;
    _current = conv;
    send(prompt ?? title, actionId: actionId);
  }

  /// Back to the overview page. Conversations (and running answers) are kept.
  void showOverview() {
    _current = null;
    notifyListeners();
  }

  Future<void> send(String text, {String? actionId}) async {
    final trimmed = text.trim();
    if (busy || trimmed.isEmpty) return;

    // Free-form question on the overview starts a new conversation.
    final conv = _current ??= () {
      final c = Conversation(id: 'chat-${_seq++}', title: trimmed);
      _conversations[c.id] = c;
      return c;
    }();

    conv.messages.add(ChatMessage(role: Role.user, isAction: actionId != null)
      ..parts.add(TextPart(trimmed)));
    final reply = ChatMessage(role: Role.assistant);
    conv.messages.add(reply);
    conv.updatedAt = DateTime.now();
    _running = conv;
    _cancelled = false;
    agent.useSession(conv.id);
    notifyListeners();

    try {
      await for (final event in agent.send(trimmed, actionId: actionId)) {
        if (_cancelled) break;
        _apply(reply, event);
        notifyListeners();
      }
    } catch (e) {
      reply.parts.add(BlockPart(FindingBlock(
          title: 'Something went wrong', body: '$e', severity: Severity.critical)));
    }

    if (_cancelled) {
      for (final s in reply.steps) {
        if (s.status == StepStatus.running) s.status = StepStatus.failed;
      }
      reply.parts.add(TextPart('Stopped.'));
    }
    reply.done = true;
    reply.finishedAt = DateTime.now();
    conv.updatedAt = DateTime.now();
    _running = null;
    notifyListeners();
  }

  void runAction(ActionsBlock block, ActionItem action) {
    if (busy || block.chosenId != null) return;
    block.chosenId = action.id;
    send(action.label, actionId: action.id);
  }

  void ask(FollowUpsBlock block, String question) {
    if (busy) return;
    block.asked.add(question);
    send(question);
  }

  void stop() {
    if (busy) _cancelled = true;
  }

  /// Forget everything (all conversations and agent histories).
  void clearAll() {
    if (busy) _cancelled = true;
    _conversations.clear();
    _current = null;
    agent.reset();
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
