import 'package:objectbox/objectbox.dart';

/// Message status constants
class MessageStatus {
  static const int pending = 0;
  static const int sent = 1;
  static const int delivered = 2;
  static const int read = 3;
  static const int failed = -1;
}

/// Local conversation stored in ObjectBox.
///
/// This is the LOCAL source of truth for conversations.
/// UI reads directly from ObjectBox - NEVER waits for network.
@Entity()
class LocalConversation {
  @Id()
  int localId = 0;

  /// Firebase document ID
  @Unique()
  String firestoreId;

  /// Participant UIDs stored as comma-separated string
  String participantsJson;

  /// Last message preview
  String? lastMessageText;
  String? lastMessageType;
  String? lastMessageSenderId;

  @Property(type: PropertyType.date)
  DateTime? lastMessageAt;

  /// Delta sync timestamp - only fetch messages after this
  @Property(type: PropertyType.date)
  DateTime lastSyncedAt;

  /// Unread count for badge
  int unreadCount;

  /// Group chat fields
  bool isGroup;
  String? groupName;
  String? groupImageUrl;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  LocalConversation({
    required this.firestoreId,
    required this.participantsJson,
    this.lastMessageText,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.lastSyncedAt,
    this.unreadCount = 0,
    this.isGroup = false,
    this.groupName,
    this.groupImageUrl,
    required this.createdAt,
  });

  /// Get participants as list
  List<String> get participants {
    if (participantsJson.isEmpty) return [];
    return participantsJson.split(',');
  }

  /// Set participants from list
  set participants(List<String> value) {
    participantsJson = value.join(',');
  }

  /// Get the other participant ID (for 1:1 chats)
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}

/// Local message stored in ObjectBox.
///
/// Messages are saved locally FIRST, then synced to server.
/// UI reads directly from ObjectBox for instant rendering.
@Entity()
class LocalMessage {
  @Id()
  int localId = 0;

  /// Firebase document ID (null if not yet synced)
  String? firestoreId;

  /// Conversation this message belongs to
  @Index()
  String conversationId;

  String senderId;
  String? receiverId;

  /// Message content
  String content;
  String type; // text, image, video, gif, show_card, video_link, recommendation

  /// Media attachment
  String? mediaUrl;

  /// Show card fields (Finishd-specific)
  String? movieId;
  String? movieTitle;
  String? moviePoster;
  String? mediaType; // movie, tv

  /// Video link fields
  String? videoId;
  String? videoTitle;
  String? videoThumbnail;
  String? videoChannel;

  @Property(type: PropertyType.date)
  DateTime createdAt;

  /// Message status: 0=pending, 1=sent, 2=delivered, 3=read, -1=failed
  int status;

  /// Retry counter for failed sends
  int retryCount;

  /// True if message is waiting to be synced
  bool isPending;

  /// True if this message was read by recipient
  bool isRead;

  LocalMessage({
    this.firestoreId,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    required this.content,
    required this.type,
    this.mediaUrl,
    this.movieId,
    this.movieTitle,
    this.moviePoster,
    this.mediaType,
    this.videoId,
    this.videoTitle,
    this.videoThumbnail,
    this.videoChannel,
    required this.createdAt,
    this.status = MessageStatus.pending,
    this.retryCount = 0,
    this.isPending = true,
    this.isRead = false,
  });

  /// Check if message is a media message
  bool get isMediaMessage =>
      type == 'image' || type == 'video' || type == 'gif';

  /// Check if message is a show card
  bool get isShowCard => type == 'show_card' || type == 'recommendation';

  /// Check if message is a video link
  bool get isVideoLink => type == 'video_link' && videoId != null;

  /// Convert to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': content,
      'type': type,
      'mediaUrl': mediaUrl ?? '',
      'timestamp': createdAt,
      'isRead': isRead,
      if (movieId != null) 'movieId': movieId,
      if (movieTitle != null) 'movieTitle': movieTitle,
      if (moviePoster != null) 'moviePoster': moviePoster,
      if (mediaType != null) 'mediaType': mediaType,
      if (videoId != null) 'videoId': videoId,
      if (videoTitle != null) 'videoTitle': videoTitle,
      if (videoThumbnail != null) 'videoThumbnail': videoThumbnail,
      if (videoChannel != null) 'videoChannel': videoChannel,
    };
  }
}

/// Local participant for group chats and presence tracking.
@Entity()
class LocalParticipant {
  @Id()
  int localId = 0;

  @Index()
  String conversationId;

  String uid;
  String username;
  String? profileImage;

  @Property(type: PropertyType.date)
  DateTime? lastSeenAt;

  bool isTyping;
  bool isOnline;

  LocalParticipant({
    required this.conversationId,
    required this.uid,
    required this.username,
    this.profileImage,
    this.lastSeenAt,
    this.isTyping = false,
    this.isOnline = false,
  });
}

/// Pending message queue entry for offline sync.
@Entity()
class PendingMessageQueue {
  @Id()
  int localId = 0;

  /// Reference to LocalMessage.localId
  int messageLocalId;

  @Property(type: PropertyType.date)
  DateTime queuedAt;

  int retryCount;
  String? lastError;

  PendingMessageQueue({
    required this.messageLocalId,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastError,
  });
}
