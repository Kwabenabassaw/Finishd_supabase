import 'dart:io';
import 'package:finishd/Chat/media_preview_screen.dart';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/Widget/message_bubble.dart';
import 'package:finishd/Widget/report_bottom_sheet.dart';
import 'package:finishd/models/report_model.dart';
import 'package:finishd/db/objectbox/chat_entities.dart';
import 'package:finishd/provider/chat_provider.dart';
import 'package:finishd/provider/community_provider.dart';
import 'package:finishd/Community/post_detail_screen.dart';
import 'package:finishd/services/storage_service.dart';
import 'package:finishd/MovieDetails/MovieScreen.dart';
import 'package:finishd/MovieDetails/Tvshowscreen.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finishd/provider/app_navigation_provider.dart';
import 'package:finishd/provider/youtube_feed_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:finishd/Widget/image_preview.dart';
import 'package:finishd/profile/profileScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({super.key, required this.chatId, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _showEmojiPicker = false;
  bool _isUploadingMedia = false;
  final FocusNode _focusNode = FocusNode();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().openConversation(widget.chatId);
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Note: Don't call closeConversation here if you want it to stay open when navigating away
    // but usually we close it to stop the stream.
    // context.read<ChatProvider>().closeConversation(); // Can't use context in dispose safely if unmounted
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    context.read<ChatProvider>().sendTextMessage(
      conversationId: widget.chatId,
      receiverId: widget.otherUser.uid,
      text: _messageController.text.trim(),
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
    if (_showEmojiPicker) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndPreviewMedia(ImageSource.gallery, 'image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndPreviewMedia(ImageSource.camera, 'image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndPreviewMedia(ImageSource.gallery, 'video');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndPreviewMedia(ImageSource source, String type) async {
    try {
      XFile? pickedFile;
      if (type == 'image') {
        pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1200,
        );
      } else {
        pickedFile = await _imagePicker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 60),
        );
      }

      if (pickedFile == null) return;

      if (!mounted) return;

      // Navigate to Preview Screen
      final String? caption = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MediaPreviewScreen(file: File(pickedFile!.path), type: type),
        ),
      );

      if (caption == null) return; // User cancelled

      setState(() => _isUploadingMedia = true);

      final mediaUrl = type == 'image'
          ? await _storageService.uploadChatImage(
              widget.chatId,
              File(pickedFile.path),
            )
          : await _storageService.uploadChatVideo(
              widget.chatId,
              File(pickedFile.path),
            );

      if (!mounted) return;

      if (type == 'image') {
        await context.read<ChatProvider>().sendImageMessage(
          conversationId: widget.chatId,
          receiverId: widget.otherUser.uid,
          mediaUrl: mediaUrl,
          caption: caption,
        );
      } else {
        await context.read<ChatProvider>().sendVideoMessage(
          conversationId: widget.chatId,
          receiverId: widget.otherUser.uid,
          mediaUrl: mediaUrl,
          caption: caption,
        );
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send ${type}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _showReportSheet(BuildContext context, LocalMessage message) {
    if (message.firestoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot report unsynced message")),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportBottomSheet(
        type: ReportType.chatMessage,
        contentId: message.firestoreId!,
        reportedUserId: message.senderId,
        chatId: widget.chatId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () {
            context.read<ChatProvider>().closeConversation();
            Navigator.of(context).pop();
          },
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(uid: widget.otherUser.uid),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.otherUser.profileImage.isNotEmpty
                    ? NetworkImage(widget.otherUser.profileImage)
                    : null,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                child: widget.otherUser.profileImage.isEmpty
                    ? Text(
                        widget.otherUser.username[0].toUpperCase(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[800],
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.username,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          context.read<ChatProvider>().closeConversation();
          return true;
        },
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final messages = chatProvider.messages;

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == _currentUserId;

                      return GestureDetector(
                        onLongPress: isMe
                            ? null
                            : () => _showReportSheet(context, message),
                        child: MessageBubble(
                          text: message.content,
                          isMe: isMe,
                          timestamp: Timestamp.fromDate(message.createdAt),
                          isRead: message.isRead,
                          type: message.type,
                          mediaUrl: message.mediaUrl,
                          videoId: message.videoId,
                          videoTitle: message.videoTitle,
                          videoThumbnail: message.videoThumbnail,
                          videoChannel: message.videoChannel,
                          onVideoTap: message.isVideoLink
                              ? () {
                                  final navProvider = context
                                      .read<AppNavigationProvider>();
                                  final ytProvider = context
                                      .read<YoutubeFeedProvider>();

                                  ytProvider.injectAndPlayVideo(
                                    videoId: message.videoId!,
                                    title: message.videoTitle,
                                    thumbnail: message.videoThumbnail,
                                    channel: message.videoChannel,
                                  );

                                  navProvider.setTab(0);
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
                                }
                              : null,
                          movieId: message.movieId,
                          movieTitle: message.movieTitle,
                          moviePoster: message.moviePoster,
                          mediaType: message.mediaType,
                          postId: message.postId,
                          postContent: message.postContent,
                          postAuthorName: message.postAuthorName,
                          postShowTitle: message.postShowTitle,
                          onPostTap: message.type == 'shared_post'
                              ? () async {
                                  final postId = message.postId;
                                  final showId = message.showId;
                                  if (postId == null || showId == null) return;

                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF1A8927),
                                      ),
                                    ),
                                  );

                                  try {
                                    final provider = context
                                        .read<CommunityProvider>();
                                    final post = await provider.getPost(postId);

                                    if (!mounted) return;
                                    Navigator.pop(context); // Close loading

                                    if (post != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PostDetailScreen(
                                                post: post,
                                                showId: showId,
                                              ),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Post no longer available',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              : null,
                          onImageTap: message.type == 'image'
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          FullscreenImagePreview(
                                            imageUrl: message.mediaUrl!,
                                            heroTag: message.mediaUrl!,
                                            caption: message.content,
                                          ),
                                    ),
                                  );
                                }
                              : null,
                          onRecommendationTap: message.isShowCard
                              ? () async {
                                  final tmdbId = int.tryParse(
                                    message.movieId ?? '',
                                  );
                                  if (tmdbId == null) return;

                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );

                                  try {
                                    final api = Trending();
                                    if (message.mediaType == 'tv') {
                                      final tvDetails = await api
                                          .fetchDetailsTvShow(tmdbId);
                                      if (context.mounted)
                                        Navigator.pop(context);
                                      if (tvDetails != null &&
                                          context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ShowDetailsScreen(
                                              movie: tvDetails,
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      final movieDetails = await api
                                          .fetchMovieDetails(tmdbId);
                                      if (context.mounted)
                                        Navigator.pop(context);
                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MovieDetailsScreen(
                                              movie: movieDetails,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) Navigator.pop(context);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error loading details: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(isDark),
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _messageController.text += emoji.emoji;
                  },
                  config: const Config(
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      columns: 7,
                      emojiSizeMax: 28,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: _isUploadingMedia
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.add_circle_outline,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 28,
                    ),
              onPressed: _isUploadingMedia ? null : _showMediaPicker,
              padding: EdgeInsets.zero,
            ),
            Expanded(
              child: Container(
                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        maxLines: 5,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _showEmojiPicker
                            ? Icons.keyboard_outlined
                            : Icons.emoji_emotions_outlined,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        size: 22,
                      ),
                      onPressed: _toggleEmojiPicker,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C853),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_upward,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
