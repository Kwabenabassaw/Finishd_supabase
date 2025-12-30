import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/models/chat_model.dart';
import 'package:finishd/models/message_model.dart';
import 'package:finishd/services/api_client.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiClient _apiClient = ApiClient();

  // Generate consistent Chat ID
  String getChatId(String userA, String userB) {
    return userA.compareTo(userB) <= 0 ? '${userA}_$userB' : '${userB}_$userA';
  }

  // Create or Get Chat
  Future<String> createChat(String userA, String userB) async {
    final chatId = getChatId(userA, userB);
    final chatDoc = _firestore.collection('chats').doc(chatId);

    final snapshot = await chatDoc.get();
    if (!snapshot.exists) {
      // Create new chat document with current timestamp so it appears in the list immediately
      final now = Timestamp.now();
      await chatDoc.set({
        'participants': [userA, userB],
        'lastMessage': '',
        'lastMessageTime': now,
        'lastMessageSender': '',
        'unreadCounts': {userA: 0, userB: 0},
        'createdAt': now,
      });
    }
    return chatId;
  }

  // Send Message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String mediaUrl = '',
  }) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    final batch = _firestore.batch();

    // Add message
    batch.set(messageRef, messageData);

    // Update chat metadata
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': type == 'image' ? '📷 Image' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': senderId,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });

    // Commit Firestore write
    await batch.commit();

    // Trigger FCM push notification via backend
    // This is non-blocking - if it fails, message is still delivered via Firestore
    _sendPushNotification(
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      chatId: chatId,
    );
  }

  /// Send Video Link with rich preview metadata
  Future<void> sendVideoLink({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String videoId,
    required String videoTitle,
    required String videoThumbnail,
    required String videoChannel,
  }) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final videoUrl = 'https://youtu.be/$videoId';

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': videoUrl,
      'type': 'video_link',
      'mediaUrl': '',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'videoThumbnail': videoThumbnail,
      'videoChannel': videoChannel,
    };

    final batch = _firestore.batch();

    // Add message
    batch.set(messageRef, messageData);

    // Update chat metadata
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': '🎬 Shared a video',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': senderId,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();

    // Trigger FCM push notification
    _sendPushNotification(
      senderId: senderId,
      receiverId: receiverId,
      text: '🎬 Shared a video: $videoTitle',
      chatId: chatId,
    );
  }

  /// Send Movie/TV Recommendation with rich preview metadata
  Future<void> sendRecommendation({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String movieId,
    required String movieTitle,
    required String? moviePoster,
    required String mediaType,
  }) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': '🎬 Recommended: $movieTitle',
      'type': 'recommendation',
      'mediaUrl': '',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'movieId': movieId,
      'movieTitle': movieTitle,
      'moviePoster': moviePoster,
      'mediaType': mediaType,
    };

    final batch = _firestore.batch();

    // Add message
    batch.set(messageRef, messageData);

    // Update chat metadata
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage':
          '🎬 Recommended a ${mediaType == 'movie' ? 'movie' : 'show'}',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': senderId,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });

    await batch.commit();

    // Trigger FCM push notification
    _sendPushNotification(
      senderId: senderId,
      receiverId: receiverId,
      text: '🎬 Recommended: $movieTitle',
      chatId: chatId,
    );
  }

  /// Send an image message
  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String mediaUrl,
  }) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: '',
      type: 'image',
      mediaUrl: mediaUrl,
    );
  }

  /// Send a video message with auto-generated thumbnail
  Future<void> sendVideoMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String mediaUrl,
  }) async {
    await sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      text: '',
      type: 'video',
      mediaUrl: mediaUrl,
    );
  }

  // Get Messages Stream
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Message.fromDocument(doc)).toList();
        });
  }

  // Load More Messages (Pagination)
  Future<List<Message>> loadMoreMessages(
    String chatId,
    DocumentSnapshot lastDocument,
  ) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDocument)
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => Message.fromDocument(doc)).toList();
  }

  // Get Chat List Stream
  Stream<List<Chat>> getChatListStream(String userId) {
    print('🔍 Fetching chats for user: $userId');
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        // Temporarily removed orderBy to test if index is the issue
        // .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
          print('❌ Error in getChatListStream: $error');
          // If it's an index error, it will be logged here
        })
        .map((snapshot) {
          print('📱 Got ${snapshot.docs.length} chats for user $userId');
          if (snapshot.docs.isEmpty) {
            print('⚠️ No chat documents found. Check Firestore console.');
          }
          final chats = snapshot.docs.map((doc) {
            print('  - Chat ID: ${doc.id}, Data: ${doc.data()}');
            return Chat.fromDocument(doc);
          }).toList();

          // Sort in memory instead
          chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          return chats;
        });
  }

  // Mark Messages as Read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);

    // Reset unread count for the user
    await chatRef.update({'unreadCounts.$userId': 0});

    // Ideally, update individual messages too, but that's expensive for many messages.
    // For now, we rely on the chat-level unread count for the UI badge.
  }

  // Set Typing Status (Optional - requires Realtime Database or Firestore listener optimization)
  // For Firestore, frequent writes can be costly. Use with caution or debounce.
  Future<void> setTypingStatus(
    String chatId,
    String userId,
    bool isTyping,
  ) async {
    // Implementation depends on preference.
    // A simple way is a subcollection or a field in the chat document.
    // await _firestore.collection('chats').doc(chatId).update({
    //   'typing.$userId': isTyping
    // });
  }

  /// Send push notification via backend
  /// This is called asynchronously after Firestore write
  /// Non-blocking: if it fails, message is still delivered via Firestore
  void _sendPushNotification({
    required String senderId,
    required String receiverId,
    required String text,
    required String chatId,
  }) {
    // Fire-and-forget: don't await or block message send
    _apiClient
        .sendChatNotification(
          receiverUid: receiverId,
          senderUid: senderId,
          messageText: text,
          chatId: chatId,
        )
        .catchError((error) {
          print('⚠️ Chat notification failed (non-critical): $error');
          return false; // Return false on error
        });
  }
}
