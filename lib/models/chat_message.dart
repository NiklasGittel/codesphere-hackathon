import 'ui_block.dart';

enum Role { user, assistant }

enum StepStatus { running, done, failed }

/// One unit of background work the agent does ("Querying CloudWatch…").
class AgentStep {
  AgentStep({required this.id, required this.label, this.source})
      : startedAt = DateTime.now();
  final String id;
  final String label;

  /// Provider id (aws, gcp, azure, codesphere) or null.
  final String? source;
  final DateTime startedAt;
  StepStatus status = StepStatus.running;
  String? detail;
  Duration? took;
}

sealed class MessagePart {}

class TextPart extends MessagePart {
  TextPart(this.text);
  String text;
}

class BlockPart extends MessagePart {
  BlockPart(this.block);
  final UiBlock block;
}

class ChatMessage {
  ChatMessage({required this.role, this.isAction = false})
      : id = 'm${_seq++}',
        createdAt = DateTime.now();

  static int _seq = 0;

  final String id;
  final Role role;

  /// User message that was triggered by clicking an action button.
  final bool isAction;
  final DateTime createdAt;
  final List<MessagePart> parts = [];
  final List<AgentStep> steps = [];
  bool done = false;
  DateTime? finishedAt;
}
