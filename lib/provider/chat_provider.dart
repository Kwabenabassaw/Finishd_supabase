import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:finishd/db/objectbox/chat_entities.dart';
import 'package:finishd/services/chat_sync_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:finishd/Model/user_model.dart';

/// Provider for offline-first chat functionality.
///
/// Bridges the ChatSyncService with the UI layer.
/// All data comes from ObjectBox (local) with background sync to Firebase.
class ChatProvider with ChangeNotifier {
  final ChatSyncService _syncService = ChatSyncService.instance;
  final UserService _userService = UserService();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Conversations
  List<LocalConversation> _conversations = [];
  List<LocalConversation> get conversations => _conversations;
  StreamSubscription? _convSub;

  // Messages for current conversation
  List<LocalMessage> _messages = [];
  List<LocalMessage> get messages => _messages;
  StreamSubscription? _msgSub;
  String? _currentConversationId;

  // User cache for display
  final Map<String, UserModel> _userCache = {};

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSending = false;
  bool get isSending => _isSending;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  void initialize() {
    _subscribeToConversations();

    // Listen to user changes to re-sync
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        print(
          '👤 [ChatProvider] User signed in: ${user.uid}, syncing chats...',
        );
        _subscribeToConversations();
        refreshConversations();
      } else {
        _conversations = [];
        _messages = [];
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _convSub?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }

  // ============================================================
  // CONVERSATION LIST
  // ============================================================

  void _subscribeToConversations() {
    _convSub?.cancel();
    _convSub = _syncService.watchConversations().listen((convs) {
      _conversations = convs;
      notifyListeners();
    });
  }

  /// Get the other user for a conversation (with caching).
  Future<UserModel?> getOtherUser(LocalConversation conv) async {
    final otherUid = conv.getOtherParticipantId(_currentUserId);
    if (otherUid.isEmpty) return null;

    if (_userCache.containsKey(otherUid)) {
      return _userCache[otherUid];
    }

    final user = await _userService.getUser(otherUid);
    if (user != null) {
      _userCache[otherUid] = user;
    }
    return user;
  }

  /// Refresh conversations from server.
  Future<void> refreshConversations() async {
    _isLoading = true;
    notifyListeners();

    await _syncService.forceSync();

    _isLoading = false;
    notifyListeners();
  }

  // ============================================================
  // MESSAGES FOR A CONVERSATION
  // ============================================================

  /// Open a conversation and start watching messages.
  void openConversation(String conversationId) {
    if (_currentConversationId == conversationId) return;

    _currentConversationId = conversationId;
    _messages = [];
    notifyListeners();

    _msgSub?.cancel();
    _msgSub = _syncService.watchMessages(conversationId).listen((msgs) {
      _messages = msgs;
      notifyListeners();
    });

    // Mark as read
    _syncService.markAsRead(conversationId);

    // Sync this conversation
    _syncService.syncConversation(conversationId);
  }

  /// Close current conversation.
  void closeConversation() {
    _msgSub?.cancel();
    _msgSub = null;
    _currentConversationId = null;
    _messages = [];
  }

  // ============================================================
  // SENDING MESSAGES
  // ============================================================

  /// Send a text message.
  Future<void> sendTextMessage({
    required String conversationId,
    required String receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;

    _isSending = true;
    notifyListeners();

    await _syncService.sendTextMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      text: text.trim(),
    );

    _isSending = false;
    notifyListeners();
  }

  /// Send an image message with optional caption.
  Future<void> sendImageMessage({
    required String conversationId,
    required String receiverId,
    required String mediaUrl,
    String? caption,
  }) async {
    _isSending = true;
    notifyListeners();

    await _syncService.sendImageMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      mediaUrl: mediaUrl,
      caption: caption,
    );

    _isSending = false;
    notifyListeners();
  }

  /// Send a video message with optional caption.
  Future<void> sendVideoMessage({
    required String conversationId,
    required String receiverId,
    required String mediaUrl,
    String? caption,
  }) async {
    _isSending = true;
    notifyListeners();

    await _syncService.sendVideoMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      mediaUrl: mediaUrl,
      caption: caption,
    );

    _isSending = false;
    notifyListeners();
  }

  /// Send a GIF message.
  Future<void> sendGifMessage({
    required String conversationId,
    required String receiverId,
    required String gifUrl,
    String? caption,
  }) async {
    _isSending = true;
    notifyListeners();

    await _syncService.sendGifMessage(
      conversationId: conversationId,
      receiverId: receiverId,
      gifUrl: gifUrl,
      caption: caption,
    );

    _isSending = false;
    notifyListeners();
  }

  /// Send a movie/show recommendation.
  Future<void> sendShowCard({
    required String conversationId,
    required String receiverId,
    required String movieId,
    required String movieTitle,
    String? moviePoster,
    String mediaType = 'movie',
  }) async {
    _isSending = true;
    notifyListeners();

    await _syncService.sendShowCard(
      conversationId: conversationId,
      receiverId: receiverId,
      movieId: movieId,
      movieTitle: movieTitle,
      moviePoster: moviePoster,
      mediaType: mediaType,
    );

    _isSending = false;
    notifyListeners();
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  /// Get pending message count (for retry indicator).
  int get pendingCount => _syncService.pendingMessageCount;

  /// Get chat ID for two users (same logic as ChatService).
  String getChatId(String userA, String userB) {
    return userA.compareTo(userB) <= 0 ? '${userA}_$userB' : '${userB}_$userA';
  }

  /// Create or get a conversation with another user.
  Future<String> getOrCreateConversation(String otherUserId) async {
    final chatId = getChatId(_currentUserId, otherUserId);

    // This will sync or create the conversation
    await _syncService.syncConversation(chatId);

    return chatId;
  }

  /// Share a community post.
  Future<void> sendPostLink({
    required String conversationId,
    required String receiverId,
    required String postId,
    required String postContent,
    required String authorName,
    required String showTitle,
    required int showId,
  }) async {
    _isSending = true;
    notifyListeners();

    await _syncService.sendPostLink(
      conversationId: conversationId,
      receiverId: receiverId,
      postId: postId,
      postContent: postContent,
      authorName: authorName,
      showTitle: showTitle,
      showId: showId,
    );

    _isSending = false;
    notifyListeners();
  }
}
