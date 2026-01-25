import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/db/objectbox/chat_entities.dart';
import 'package:finishd/db/objectbox/objectbox_store.dart';
import 'package:finishd/objectbox.g.dart';

/// Offline-first chat sync service.
///
/// Core principles:
/// 1. Local DB (ObjectBox) is the single source of truth
/// 2. UI only reads from ObjectBox - never waits for network
/// 3. Messages are saved locally FIRST, then queued for sync
/// 4. Delta sync: only fetch messages newer than lastSyncedAt
class ChatSyncService {
  static ChatSyncService? _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  late final Box<LocalConversation> _convBox;
  late final Box<LocalMessage> _msgBox;
  late final Box<LocalParticipant> _participantBox;
  late final Box<PendingMessageQueue> _queueBox;

  final Queue<int> _pendingQueue = Queue();
  Timer? _queueProcessor;
  StreamSubscription? _connectivitySub;
  StreamSubscription? _globalConvsSub;
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

    // Start global real-time listener
    _startGlobalListener();

    print(
      '✅ [ChatSync] Initialized with ${_pendingQueue.length} pending messages',
    );
    print(
      '🗄️ [ChatSync] Local DB ready - ${_convBox.count()} conversations, ${_msgBox.count()} messages',
    );
  }

  void dispose() {
    _queueProcessor?.cancel();
    _connectivitySub?.cancel();
    _globalConvsSub?.cancel();
  }

  /// Clear all local chat data.
  /// Call this on logout to prevent data leaking between accounts.
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
  /// Call this after login when user changes.
  Future<void> reinitialize() async {
    print('🔄 [ChatSync] Re-initializing for new user...');
    _globalConvsSub?.cancel();
    await clearLocalData();
    await syncAllConversations();
    _startGlobalListener();
    print('✅ [ChatSync] Re-initialized for user: $_currentUserId');
  }

  // ============================================================
  // CONVERSATION STREAMS (UI reads these)
  // ============================================================

  /// Watch all conversations for current user.
  /// Filters to only show conversations where current user is a participant.
  Stream<List<LocalConversation>> watchConversations() {
    print(
      '👀 [ChatSync] UI subscribing to conversations for user: $_currentUserId',
    );

    // ObjectBox doesn't support 'contains' on strings well, so we filter in Dart
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
          print(
            '📱 [ChatSync] UI received ${userConvs.length} conversations from LOCAL DB (filtered from ${allConvs.length} total)',
          );
          return userConvs;
        });
  }

  /// Watch messages for a specific conversation.
  Stream<List<LocalMessage>> watchMessages(String conversationId) {
    print(
      '👀 [ChatSync] UI subscribing to messages for $conversationId (ObjectBox)',
    );
    return _msgBox
        .query(LocalMessage_.conversationId.equals(conversationId))
        .order(LocalMessage_.createdAt, flags: Order.descending)
        .watch(triggerImmediately: true)
        .map((q) {
          final msgs = q.find();
          print(
            '💬 [ChatSync] UI received ${msgs.length} messages from LOCAL DB',
          );
          return msgs;
        });
  }

  // ============================================================
  // MESSAGE SENDING (Optimistic)
  // ============================================================

  /// Send a text message - saves locally immediately.
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

  /// Send an image message with optional caption.
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

  /// Send a video message with optional caption.
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

  /// Send a GIF message.
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

  /// Share a community post.
  Future<LocalMessage> sendPostLink({
    required String conversationId,
    required String receiverId,
    required String postId,
    required String postContent,
    required String authorName,
    required String showTitle,
    required int showId,
  }) async {
    // DEBUG: Log the incoming data
    print('[ChatSync] 📝 sendPostLink called:');
    print('  - postId: $postId');
    print(
      '  - postContent: ${postContent.substring(0, postContent.length.clamp(0, 30))}...',
    );
    print('  - authorName: $authorName');
    print('  - showTitle: $showTitle');

    final message = LocalMessage(
      conversationId: conversationId,
      senderId: _currentUserId,
      receiverId: receiverId,
      content: postContent,
      type: 'shared_post',
      postId: postId,
      postContent: postContent,
      postAuthorName: authorName,
      postShowTitle: showTitle,
      showId: showId,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      isPending: true,
    );

    return _saveAndQueueMessage(message);
  }

  /// Send a show/movie recommendation card.
  Future<LocalMessage> sendShowCard({
    required String conversationId,
    required String receiverId,
    required String movieId,
    required String movieTitle,
    String? moviePoster,
    String mediaType = 'movie',
  }) async {
    final message = LocalMessage(
      conversationId: conversationId,
      senderId: _currentUserId,
      receiverId: receiverId,
      content: '🎬 Recommended: $movieTitle',
      type: 'recommendation',
      movieId: movieId,
      movieTitle: movieTitle,
      moviePoster: moviePoster,
      mediaType: mediaType,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
      isPending: true,
    );

    return _saveAndQueueMessage(message);
  }

  LocalMessage _saveAndQueueMessage(LocalMessage message) {
    // 1. Save to local DB immediately
    final id = _msgBox.put(message);
    message.localId = id;

    // 2. Update conversation preview
    _updateConversationPreview(message);

    // 3. Add to pending queue
    _queueBox.put(
      PendingMessageQueue(messageLocalId: id, queuedAt: DateTime.now()),
    );
    _pendingQueue.add(id);

    // 4. Trigger processing if online
    if (_isOnline) {
      _processPendingQueue();
    }

    return message;
  }

  void _updateConversationPreview(LocalMessage message) {
    final conv = _convBox
        .query(LocalConversation_.firestoreId.equals(message.conversationId))
        .build()
        .findFirst();

    if (conv != null) {
      conv.lastMessageText = message.type == 'text'
          ? message.content
          : _getMessagePreview(message.type);
      conv.lastMessageType = message.type;
      conv.lastMessageAt = message.createdAt;
      conv.lastMessageSenderId = message.senderId;
      _convBox.put(conv);
    }
  }

  String _getMessagePreview(String type) {
    switch (type) {
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎥 Video';
      case 'gif':
        return 'GIF';
      case 'recommendation':
        return '🎬 Recommendation';
      case 'shared_post':
        return '📝 Shared Post';
      default:
        return 'Message';
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

    final messageId = _pendingQueue.removeFirst();
    final message = _msgBox.get(messageId);
    if (message == null) return;

    try {
      // Upload to Firestore
      final docRef = await _firestore
          .collection('chats')
          .doc(message.conversationId)
          .collection('messages')
          .add(message.toFirestore());

      // Update local with server ID
      message.firestoreId = docRef.id;
      message.isPending = false;
      message.status = MessageStatus.sent;
      _msgBox.put(message);

      // Remove from queue
      final queueEntry = _queueBox
          .query(PendingMessageQueue_.messageLocalId.equals(messageId))
          .build()
          .findFirst();
      if (queueEntry != null) {
        _queueBox.remove(queueEntry.localId);
      }

      // Update chat metadata in Firestore
      await _firestore.collection('chats').doc(message.conversationId).update({
        'lastMessage': message.type == 'text' ? message.content : '📷 Media',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': message.senderId,
        'unreadCounts.${message.receiverId}': FieldValue.increment(1),
        if (message.type == 'shared_post') 'lastMessageType': 'shared_post',
      });

      print(
        '✅ [ChatSync] Message sent to Firebase: localId=${message.localId}, firestoreId=${docRef.id}',
      );
    } catch (e) {
      print('❌ [ChatSync] SEND FAILED: $e');

      // Update retry count
      final queueEntry = _queueBox
          .query(PendingMessageQueue_.messageLocalId.equals(messageId))
          .build()
          .findFirst();

      if (queueEntry != null) {
        queueEntry.retryCount++;
        queueEntry.lastError = e.toString();

        if (queueEntry.retryCount < 5) {
          _queueBox.put(queueEntry);
          _pendingQueue.add(messageId); // Re-queue
        } else {
          // Mark as failed
          message.status = MessageStatus.failed;
          _msgBox.put(message);
          _queueBox.remove(queueEntry.localId);
        }
      }
    }
  }

  // ============================================================
  // RECEIVING (Delta Sync)
  // ============================================================

  Future<void> syncAllConversations() async {
    try {
      final uid = _currentUserId;
      if (uid.isEmpty) {
        print('⚠️ [ChatSync] Cannot sync conversations: No user logged in');
        return;
      }

      // Get all conversations for current user
      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      for (final doc in snapshot.docs) {
        await _syncConversation(doc);
      }
    } catch (e) {
      print('❌ [ChatSync] SYNC ALL FAILED: $e');
    }
  }

  Future<void> syncConversation(String conversationId) async {
    try {
      final doc = await _firestore
          .collection('chats')
          .doc(conversationId)
          .get();
      if (doc.exists) {
        await _syncConversation(doc);
      }
    } catch (e) {
      print('❌ [ChatSync] SYNC CONVERSATION FAILED: $e');
    }
  }

  Future<void> _syncConversation(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final convId = doc.id;

    // Get or create local conversation
    var conv = _convBox
        .query(LocalConversation_.firestoreId.equals(convId))
        .build()
        .findFirst();

    if (conv == null) {
      conv = LocalConversation(
        firestoreId: convId,
        participantsJson: (data['participants'] as List).join(','),
        lastSyncedAt: DateTime(2020),
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
      _convBox.put(conv);
    }

    // Delta sync: only fetch messages after lastSyncedAt
    final lastSync = conv.lastSyncedAt;

    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(convId)
        .collection('messages')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(lastSync))
        .orderBy('timestamp')
        .get();

    int newCount = 0;
    for (final msgDoc in messagesSnapshot.docs) {
      // Skip if already exists locally
      final existing = _msgBox
          .query(LocalMessage_.firestoreId.equals(msgDoc.id))
          .build()
          .findFirst();

      if (existing == null) {
        final msgData = msgDoc.data();
        final message = LocalMessage(
          firestoreId: msgDoc.id,
          conversationId: convId,
          senderId: msgData['senderId'] ?? '',
          receiverId: msgData['receiverId'],
          content: msgData['text'] ?? '',
          type: msgData['type'] ?? 'text',
          mediaUrl: msgData['mediaUrl'],
          movieId: msgData['movieId'],
          movieTitle: msgData['movieTitle'],
          moviePoster: msgData['moviePoster'],
          mediaType: msgData['mediaType'],
          videoId: msgData['videoId'],
          videoTitle: msgData['videoTitle'],
          videoThumbnail: msgData['videoThumbnail'],
          videoChannel: msgData['videoChannel'],
          postId: msgData['postId'],
          postContent: msgData['postContent'],
          postAuthorName: msgData['postAuthorName'],
          postShowTitle: msgData['postShowTitle'],
          createdAt:
              (msgData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          status: MessageStatus.delivered,
          isPending: false,
          isRead: msgData['isRead'] ?? false,
        );
        _msgBox.put(message);
        newCount++;
      }
    }

    // Update conversation metadata
    if (messagesSnapshot.docs.isNotEmpty || conv.lastMessageAt == null) {
      conv.lastSyncedAt = DateTime.now();
      conv.lastMessageText = data['lastMessage'];
      conv.lastMessageAt = (data['lastMessageTime'] as Timestamp?)?.toDate();
      conv.lastMessageSenderId = data['lastMessageSender'];

      // Update unread count for current user
      final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
      conv.unreadCount = unreadCounts?[_currentUserId] ?? 0;

      _convBox.put(conv);
    }

    if (newCount > 0) {
      print(
        '🔄 [ChatSync] SYNCED $newCount new messages from Firebase → ObjectBox for $convId',
      );
    }
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  /// Mark messages as read locally and sync to server.
  Future<void> markAsRead(String conversationId) async {
    // Update local
    final conv = _convBox
        .query(LocalConversation_.firestoreId.equals(conversationId))
        .build()
        .findFirst();

    if (conv != null) {
      conv.unreadCount = 0;
      _convBox.put(conv);
    }

    // Sync to server
    if (_isOnline) {
      try {
        await _firestore.collection('chats').doc(conversationId).update({
          'unreadCounts.$_currentUserId': 0,
        });
      } catch (e) {
        print('❌ [ChatSync] MARK READ FAILED: $e');
      }
    }
  }

  /// Get pending message count for UI.
  int get pendingMessageCount => _pendingQueue.length;

  /// Force sync all (for pull-to-refresh).
  Future<void> forceSync() async {
    await syncAllConversations();
    if (_isOnline) {
      await _processPendingQueue();
    }
  }

  // ============================================================
  // REAL-TIME LISTENER
  // ============================================================

  void _startGlobalListener() {
    _globalConvsSub?.cancel();

    final uid = _currentUserId;
    if (uid.isEmpty) return;

    print('📡 [ChatSync] Starting global real-time listener for user: $uid');

    _globalConvsSub = _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added ||
                  change.type == DocumentChangeType.modified) {
                final doc = change.doc;
                print(
                  '🔔 [ChatSync] Real-time change detected for conversation: ${doc.id}',
                );
                _syncConversation(doc);
              }
            }
          },
          onError: (e) {
            print('❌ [ChatSync] Global listener error: $e');
          },
        );
  }
}
