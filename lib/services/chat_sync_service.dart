import 'dart:async';
import 'dart:collection';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/db/objectbox/chat_entities.dart';
import 'package:finishd/db/objectbox/objectbox_store.dart';
import 'package:finishd/objectbox.g.dart';

/// Offline-first chat sync service.
/// Migrated to Supabase with proper sync logic.
class ChatSyncService {
  static ChatSyncService? _instance;

  // Supabase Client
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  late final Box<LocalConversation> _convBox;
  late final Box<LocalMessage> _msgBox;
  late final Box<LocalParticipant> _participantBox;
  late final Box<PendingMessageQueue> _queueBox;

  final Queue<int> _pendingQueue = Queue();
  Timer? _queueProcessor;
  StreamSubscription? _connectivitySub;
  RealtimeChannel? _globalChannel;
  bool _isOnline = true;

  ChatSyncService._();

  static ChatSyncService get instance {
    _instance ??= ChatSyncService._();
    return _instance!;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    final store = ObjectBoxStore.instance.store;
    _convBox = store.box<LocalConversation>();
    _msgBox = store.box<LocalMessage>();
    _participantBox = store.box<LocalParticipant>();
    _queueBox = store.box<PendingMessageQueue>();

    // Load pending messages from DB
    _loadPendingQueue();

    // Start queue processor
    _startQueueProcessor();

    // Monitor connectivity
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      if (_isOnline) {
        _processPendingQueue();
      }
    });

    // Initial sync
    await syncAllConversations();

    // Start global real-time listener for NEW/UPDATED chats
    _startGlobalListener();

    print(
      '✅ [ChatSync] Initialized with ${_pendingQueue.length} pending messages',
    );
  }

  void dispose() {
    _queueProcessor?.cancel();
    _connectivitySub?.cancel();
    _globalChannel?.unsubscribe();
  }

  /// Clear all local chat data.
  Future<void> clearLocalData() async {
    print('🧹 [ChatSync] Clearing all local chat data...');
    _convBox.removeAll();
    _msgBox.removeAll();
    _participantBox.removeAll();
    _queueBox.removeAll();
    _pendingQueue.clear();
    print('✅ [ChatSync] Local chat data cleared');
  }

  /// Re-initialize for a new user.
  Future<void> reinitialize() async {
    print('🔄 [ChatSync] Re-initializing for new user...');
    _globalChannel?.unsubscribe();
    await clearLocalData();
    await syncAllConversations();
    _startGlobalListener();
    print('✅ [ChatSync] Re-initialized for user: $_currentUserId');
  }

  // ============================================================
  // CONVERSATION STREAMS
  // ============================================================

  Stream<List<LocalConversation>> watchConversations() {
    return _convBox
        .query()
        .order(LocalConversation_.lastMessageAt, flags: Order.descending)
        .watch(triggerImmediately: true)
        .map((q) {
          final allConvs = q.find();
          // Filter to only conversations where current user is a participant
          final userConvs = allConvs.where((conv) {
            return conv.participants.contains(_currentUserId);
          }).toList();
          return userConvs;
        });
  }

  Stream<List<LocalMessage>> watchMessages(String conversationId) {
    return _msgBox
        .query(LocalMessage_.conversationId.equals(conversationId))
        .order(LocalMessage_.createdAt, flags: Order.descending)
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  // ============================================================
  // MESSAGE SENDING (Optimistic)
  // ============================================================

  Future<LocalMessage> sendTextMessage({
    required String conversationId,
    required String receiverId,
    required String text,
  }) async {
    final message = LocalMessage(
      conversationId: conversationId,
      senderId: _currentUserId,
      receiverId: receiverId,
      content: text,
      type: 'text',
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      isPending: true,
    );
    return _saveAndQueueMessage(message);
  }

  Future<LocalMessage> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required String mediaUrl,
    String? caption,
  }) async {
    final message = LocalMessage(
      conversationId: conversationId,
      senderId: _currentUserId,
      receiverId: receiverId,
      content: caption ?? '',
      type: 'image',
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      isPending: true,
    );
    return _saveAndQueueMessage(message);
  }

  Future<LocalMessage> sendVideoMessage({
    required String conversationId,
    required String receiverId,
    required String mediaUrl,
    String? caption,
  }) async {
    final message = LocalMessage(
      conversationId: conversationId,
      senderId: _currentUserId,
      receiverId: receiverId,
      content: caption ?? '',
      type: 'video',
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      isPending: true,
    );
    return _saveAndQueueMessage(message);
  }

  Future<LocalMessage> sendGifMessage({
    required String conversationId,
    required String receiverId,
    required String gifUrl,
    String? caption,
  }) async {
    final message = LocalMessage(
      conversationId: conversationId,
      senderId: _currentUserId,
      receiverId: receiverId,
      content: caption ?? '',
      type: 'gif',
      mediaUrl: gifUrl,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      isPending: true,
    );
    return _saveAndQueueMessage(message);
  }

  Future<LocalMessage> sendPostLink({
    required String conversationId,
    required String receiverId,
    required String postId,
    required String postContent,
    required String authorName,
    required String showTitle,
    required int showId,
  }) async => sendTextMessage(
    conversationId: conversationId,
    receiverId: receiverId,
    text: postContent, // simplified
  );

  Future<LocalMessage> sendShowCard({
    required String conversationId,
    required String receiverId,
    required String movieId,
    required String movieTitle,
    String? moviePoster,
    String mediaType = 'movie',
  }) async =>
      sendTextMessage(
        conversationId: conversationId,
        receiverId: receiverId,
        text: 'Check out $movieTitle',
      ).then((m) {
        m.type = 'recommendation';
        // Store metadata in content or separate fields if LocalMessage supports it
        // For now, simple text fall back in DB, but metadata could be added to LocalMessage schema
        _msgBox.put(m);
        return m;
      });

  LocalMessage _saveAndQueueMessage(LocalMessage message) {
    final id = _msgBox.put(message);
    message.localId = id;

    // Update conversation preview
    _updateConversationPreview(message);

    _queueBox.put(
      PendingMessageQueue(messageLocalId: id, queuedAt: DateTime.now()),
    );
    _pendingQueue.add(id);

    if (_isOnline) {
      _processPendingQueue();
    }
    return message;
  }

  void _updateConversationPreview(LocalMessage message) {
    var conv = _convBox
        .query(LocalConversation_.firestoreId.equals(message.conversationId))
        .build()
        .findFirst();

    if (conv != null) {
      conv.lastMessageText = message.content;
      conv.lastMessageAt = message.createdAt;
      conv.lastMessageSenderId = message.senderId;
      _convBox.put(conv);
    } else {
      // Create local conversation stub if not exists
      final newConv = LocalConversation(
        firestoreId: message.conversationId,
        participantsJson: [_currentUserId, message.receiverId].join(','),
        lastMessageText: message.content,
        lastMessageAt: message.createdAt,
        lastMessageSenderId: message.senderId,
        lastSyncedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      _convBox.put(newConv);
    }
  }

  // ============================================================
  // QUEUE PROCESSING
  // ============================================================

  void _loadPendingQueue() {
    final pending = _queueBox.getAll();
    for (final item in pending) {
      _pendingQueue.add(item.messageLocalId);
    }
  }

  void _startQueueProcessor() {
    _queueProcessor = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isOnline && _pendingQueue.isNotEmpty) {
        _processPendingQueue();
      }
    });
  }

  Future<void> _processPendingQueue() async {
    if (_pendingQueue.isEmpty) return;

    final localId = _pendingQueue.first;
    final message = _msgBox.get(localId);

    if (message == null) {
      _pendingQueue.removeFirst();
      _removeItemFromQueue(localId);
      return; // Message deleted locally
    }

    try {
      // Insert into Supabase 'messages' table
      // Note: 'conversationId' in LocalMessage maps to 'chat_id' in Supabase

      // Ensure chat exists first?
      // We can assume chat exists or use an RPC.
      // For 1-on-1, ideally we check for existing chat between A and B if conversionId is temporary.

      final response = await _supabase
          .from('messages')
          .insert({
            'chat_id': message.conversationId, // Assuming this is UUID
            'sender_id': message.senderId,
            'content': message.content,
            'type': message.type,
            'media_url': message.mediaUrl,
            'created_at': message.createdAt.toIso8601String(),
          })
          .select()
          .single();

      // Update local status
      message.status = MessageStatus.sent;
      message.firestoreId = response['id']; // Update with definitive ID
      message.isPending = false;
      _msgBox.put(message);

      // Update Chat Metadata (Last Message)
      await _supabase
          .from('chats')
          .update({
            'last_message': message.content,
            'last_message_at': message.createdAt.toIso8601String(),
            'last_message_sender_id': message.senderId,
          })
          .eq('id', message.conversationId);

      print('📨 [ChatSync] Message sent: ${message.content}');

      // Remove from queue
      _pendingQueue.removeFirst();
      _removeItemFromQueue(localId);
    } catch (e) {
      print('❌ [ChatSync] Error sending message: $e');
      // Keep in queue, retry later
    }
  }

  void _removeItemFromQueue(int localId) {
    final query = _queueBox
        .query(PendingMessageQueue_.messageLocalId.equals(localId))
        .build();
    query.remove();
    query.close();
  }

  // ============================================================
  // RECEIVING (Delta Sync)
  // ============================================================

  Future<void> forceSync() async {
    await syncAllConversations();
  }

  int get pendingMessageCount => _pendingQueue.length;

  Future<void> syncAllConversations() async {
    try {
      final userId = _currentUserId;
      if (userId.isEmpty) return;

      // 1. Get List of Chat IDs for current User
      // select chat_id from chat_participants where user_id = me
      final participantData = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', userId);

      final chatIds = (participantData as List)
          .map((e) => e['chat_id'] as String)
          .toList();

      if (chatIds.isEmpty) return;

      // 2. Fetch Chat Metadata
      final chatsData = await _supabase
          .from('chats')
          .select()
          .filter('id', 'in', chatIds)
          .order('last_message_at', ascending: false);

      for (final chatRow in chatsData as List) {
        final chatId = chatRow['id'];

        // Upsert Local Conversation
        // Need to fetch participants for this chat to store locally
        final participantsRow = await _supabase
            .from('chat_participants')
            .select('user_id')
            .eq('chat_id', chatId);

        final participants = (participantsRow as List)
            .map((p) => p['user_id'] as String)
            .toList();

        final conv =
            _convBox
                .query(LocalConversation_.firestoreId.equals(chatId))
                .build()
                .findFirst() ??
            LocalConversation(
              firestoreId: chatId,
              participantsJson: participants.join(','),
              lastSyncedAt: DateTime.now(),
              createdAt: DateTime.now(),
            );

        conv.lastMessageText = chatRow['last_message'] ?? '';
        conv.lastMessageAt = DateTime.parse(
          chatRow['last_message_at'] ?? DateTime.now().toIso8601String(),
        );
        conv.lastMessageSenderId = chatRow['last_message_sender_id'] ?? '';
        conv.participants = participants;

        _convBox.put(conv);

        // Sync recent messages
        await syncConversation(chatId);
      }
    } catch (e) {
      print('Error syncing all conversations: $e');
    }
  }

  Future<void> syncConversation(String conversationId) async {
    try {
      // Fetch last 50 messages
      final messages = await _supabase
          .from('messages')
          .select()
          .eq('chat_id', conversationId)
          .order('created_at', ascending: false)
          .limit(50);

      for (final msgRow in messages as List) {
        final msgId = msgRow['id'];

        // Upsert Message
        final existing = _msgBox
            .query(LocalMessage_.firestoreId.equals(msgId))
            .build()
            .findFirst();

        if (existing == null) {
          final newMsg = LocalMessage(
            conversationId: conversationId,
            senderId: msgRow['sender_id'],
            receiverId:
                '', // infer from context? or not needed if we check sender != me
            content: msgRow['content'] ?? '',
            type: msgRow['type'] ?? 'text',
            mediaUrl: msgRow['media_url'] ?? '',
            createdAt: DateTime.parse(msgRow['created_at']),
            status: MessageStatus.sent,
            isPending: false,
            firestoreId: msgId,
          );
          _msgBox.put(newMsg);
        }
      }
    } catch (e) {
      print('Error syncing conversation $conversationId: $e');
    }
  }

  void _startGlobalListener() {
    // Listen for NEW messages in any chat the user is part of
    final myId = _currentUserId;
    if (myId.isEmpty) return;

    _globalChannel = _supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final newRecord = payload.newRecord;
            final chatId = newRecord['chat_id'];
            final msgId = newRecord['id'];
            final senderId = newRecord['sender_id'];

            if (senderId == myId)
              return; // Ignore own messages (handled optimistically)

            // DEDUPLICATION: Check if we already have this message
            final exists =
                _msgBox
                    .query(LocalMessage_.firestoreId.equals(msgId))
                    .build()
                    .count() >
                0;

            if (exists) {
              print(
                '⚠️ [ChatSync] Duplicate message received (ignored): $msgId',
              );
              return;
            }

            // Check if we have this chat locally
            var conv = _convBox
                .query(LocalConversation_.firestoreId.equals(chatId))
                .build()
                .findFirst();

            // If chat doesn't exist locally, we MUST fetch it or create a stub
            if (conv == null) {
              print('🆕 [ChatSync] New conversation received: $chatId');
              await _fetchAndSaveConversation(chatId);
              // Re-fetch conversation to ensure we have the object
              conv = _convBox
                  .query(LocalConversation_.firestoreId.equals(chatId))
                  .build()
                  .findFirst();
            }

            // Create Local Message
            final newMsg = LocalMessage(
              conversationId: chatId,
              senderId: senderId,
              receiverId: '', // Can be filled if we parse participants
              content: newRecord['content'] ?? '',
              type: newRecord['type'] ?? 'text',
              mediaUrl: newRecord['media_url'] ?? '',
              createdAt: DateTime.parse(newRecord['created_at']),
              status: MessageStatus.sent,
              isPending: false,
              firestoreId: msgId,
            );

            _msgBox.put(newMsg);

            // CRITICAL: Update conversation preview so the list updates!
            _updateConversationPreview(newMsg);

            print('📥 [ChatSync] Realtime message received: ${newMsg.content}');
          },
        )
        .subscribe();
  }

  /// Helper to fetch a single conversation by ID and save it locally.
  Future<void> _fetchAndSaveConversation(String chatId) async {
    try {
      final chatRow = await _supabase
          .from('chats')
          .select()
          .eq('id', chatId)
          .single();

      final participantsRow = await _supabase
          .from('chat_participants')
          .select('user_id')
          .eq('chat_id', chatId);

      final participants = (participantsRow as List)
          .map((p) => p['user_id'] as String)
          .toList();

      // Ensure current user is actually a participant before saving
      if (!participants.contains(_currentUserId)) return;

      final conv = LocalConversation(
        firestoreId: chatId,
        participantsJson: participants.join(','),
        lastSyncedAt: DateTime.now(),
        createdAt: DateTime.parse(
          chatRow['created_at'] ?? DateTime.now().toIso8601String(),
        ),
      );

      // Metadata will be updated by _updateConversationPreview later,
      // but we can set defaults here
      conv.lastMessageText = chatRow['last_message'] ?? '';
      conv.lastMessageAt = DateTime.parse(
        chatRow['last_message_at'] ?? DateTime.now().toIso8601String(),
      );
      conv.lastMessageSenderId = chatRow['last_message_sender_id'] ?? '';

      _convBox.put(conv);
    } catch (e) {
      print('❌ [ChatSync] Error fetching new conversation: $e');
    }
  }

  Future<void> markAsRead(String conversationId) async {
    // Use RPC to mark as read in chat_participants
    await _supabase.rpc(
      'mark_chat_read',
      params: {'p_chat_id': conversationId},
    );
  }
}
