import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/models/chat_model.dart';
import 'package:finishd/models/message_model.dart';

/// Legacy ChatService refactored to use Supabase for basic operations where SyncService is overkill
/// OR acting as a utility wrapper.
/// For now, simpler methods that don't need offline sync.
class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  // final ApiClient _apiClient = ApiClient();

  // Generate consistent Chat ID (UUID-based ideally, but for migration consistency...)
  // WARNING: Supabase uses UUIDs for PKs. We should ideally create a new UUID for a chat pair.
  // BUT to maintain compatibility, let's look up if a chat exists between these two users.

  // Create or Get Chat
  Future<String> createChat(String userA, String userB) async {
    try {
      // Use atomic RPC function to create chat with participants
      // This bypasses RLS timing issues where the user isn't a participant yet
      final result = await _supabase.rpc(
        'create_chat_with_participants',
        params: {'user_a': userA, 'user_b': userB},
      );

      return result as String;
    } catch (e) {
      print('Error creating chat: $e');
      rethrow;
    }
  }

  // Send Message (Directly via Supabase - bypassing SyncService if needed, but SyncService is preferred)
  // Implement stub for compatibility if legacy code calls this.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String mediaUrl = '',
  }) async {
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'content': text,
      'type': type,
      'media_url': mediaUrl,
      // 'is_read' REMOVED - not in schema
    });

    // Update chat metadata
    await _supabase
        .from('chats')
        .update({
          'last_message': type == 'image' ? '📷 Image' : text,
          'last_message_at': DateTime.now().toIso8601String(),
          'last_message_sender_id': senderId,
        })
        .eq('id', chatId);
  }

  /// Send Recommendation
  Future<void> sendRecommendation({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String movieId,
    required String movieTitle,
    required String? moviePoster,
    required String mediaType,
  }) async {
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'content': '🎬 Recommended: $movieTitle',
      'type': 'recommendation',
      'metadata': {
        'movieId': movieId,
        'movieTitle': movieTitle,
        'moviePoster': moviePoster,
        'mediaType': mediaType,
      },
    });
  }

  /// Send Video Link
  Future<void> sendVideoLink({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String videoId,
    required String videoTitle,
    required String videoThumbnail,
    required String videoChannel,
  }) async {
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'content': '🎥 Shared Video: $videoTitle',
      'type': 'video_share',
      'metadata': {
        'videoId': videoId,
        'videoTitle': videoTitle,
        'videoThumbnail': videoThumbnail,
        'videoChannel': videoChannel,
      },
    });

    // Update chat metadata
    await _supabase
        .from('chats')
        .update({
          'last_message': '🎥 Shared Video',
          'last_message_at': DateTime.now().toIso8601String(),
          'last_message_sender_id': senderId,
        })
        .eq('id', chatId);
  }

  // Get Messages Stream (Direct)
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .limit(50)
        .map((data) => data.map((json) => Message.fromSupabase(json)).toList());
  }

  // Get Chat List Stream (Direct)
  Stream<List<Chat>> getChatListStream(String userId) {
    // Stream not easily supported for joined data.
    // We stream chats, but filtering by 'my chats' is hard without joins in realtime.
    // Better to rely on ChatSyncService for this which manages local state.
    return const Stream.empty();
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    // Use RPC to update chat_participants table
    await _supabase.rpc('mark_chat_read', params: {'p_chat_id': chatId});
  }
}
