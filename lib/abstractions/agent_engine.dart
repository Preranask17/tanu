/// A chat message exchanged with the agent.
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// The reasoning brain behind Tanu. Today it is a cloud Mistral call; later it
/// may be an on-device model. The interface keeps the app agnostic.
abstract class AgentEngine {
  /// Send a single user utterance and get the agent's reply text.
  Future<String> prompt(String transcript, {List<ChatMessage>? history});
}
