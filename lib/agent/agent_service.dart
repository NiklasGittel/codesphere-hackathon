import '../models/ui_block.dart';

/// Events streamed from the agent to the UI.
sealed class AgentEvent {
  const AgentEvent();
}

class StepStarted extends AgentEvent {
  const StepStarted(this.id, this.label, {this.source});
  final String id;
  final String label;
  final String? source;
}

class StepCompleted extends AgentEvent {
  const StepCompleted(this.id, {this.detail});
  final String id;
  final String? detail;
}

class TextChunk extends AgentEvent {
  const TextChunk(this.text, {this.startsNew = false});
  final String text;

  /// Start a new paragraph instead of appending to the previous one.
  final bool startsNew;
}

class BlockEmitted extends AgentEvent {
  const BlockEmitted(this.block);
  final UiBlock block;
}

/// The seam between UI and agent.
///
/// [MockAgent] implements this with scripted scenarios. A `GeminiAgent` can
/// implement the same interface: map tool calls to [StepStarted] /
/// [StepCompleted], streamed text to [TextChunk], and a `render_ui` function
/// call to [BlockEmitted] via `UiBlock.fromJson(args)`.
abstract class AgentService {
  Stream<AgentEvent> send(String message, {String? actionId});

  /// Switch to the conversation [id]; agents with memory keep one history
  /// per conversation.
  void useSession(String id);

  /// Forget all conversations.
  void reset();
}
