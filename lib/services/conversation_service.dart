class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;
  final bool isError;
  final String? audioUrl;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.timestamp,
    this.isError = false,
    this.audioUrl,
  });
}

class ConversationService {
  static final ConversationService _instance = ConversationService._internal();

  factory ConversationService() {
    return _instance;
  }

  ConversationService._internal();

  // Store conversations by patient ID
  final Map<String, List<ChatMessage>> _conversations = {};

  List<ChatMessage> getConversation(String patientId) {
    if (!_conversations.containsKey(patientId)) {
      _conversations[patientId] = [
        ChatMessage(
          text: "Hi! I'm your cognitive health companion. How can I help you today?",
          isBot: true,
          timestamp: DateTime.now(),
        ),
      ];
    }
    return _conversations[patientId]!;
  }

  void addMessage(String patientId, ChatMessage message) {
    if (!_conversations.containsKey(patientId)) {
      _conversations[patientId] = [];
    }
    _conversations[patientId]!.add(message);
  }

  void clearConversation(String patientId) {
    _conversations[patientId] = [
      ChatMessage(
        text: "Hi! I'm your cognitive health companion. How can I help you today?",
        isBot: true,
        timestamp: DateTime.now(),
      ),
    ];
  }

  void deleteConversation(String patientId) {
    _conversations.remove(patientId);
  }
}
