class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime createdAt; // Lisätään aikaleima

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}