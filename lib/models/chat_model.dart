class Chat {
  final String chatId; // UUID
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSender;
  final Map<String, int> unreadCounts; // Derived from chat_participants?
  final DateTime createdAt;

  Chat({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.unreadCounts,
    required this.createdAt,
  });

  // Factory for Supabase (joined query result)
  // Assumes structure: { id, last_message, ... , chat_participants: [{user_id, unread_count}] }
  factory Chat.fromSupabase(Map<String, dynamic> data) {
    // Parse participants from joined table
    final participantsList = (data['chat_participants'] as List?) ?? [];
    final List<String> participantIds = participantsList
        .map((p) => p['user_id'] as String)
        .toList();

    final Map<String, int> unreadMap = {};
    for (var p in participantsList) {
      unreadMap[p['user_id']] = p['unread_count'] ?? 0;
    }

    return Chat(
      chatId: data['id'],
      participants: participantIds,
      lastMessage: data['last_message'] ?? '',
      lastMessageTime:
          DateTime.tryParse(data['last_message_at'] ?? '') ?? DateTime.now(),
      lastMessageSender: data['last_message_sender_id'] ?? '',
      unreadCounts: unreadMap,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Legacy Factory for temporary compat if needed, simplified
  // factory Chat.fromDocument(DocumentSnapshot doc) => ... REMOVED
}
