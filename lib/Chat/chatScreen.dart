import 'package:finishd/Model/user_model.dart';
import 'package:finishd/Widget/message_bubble.dart';
import 'package:finishd/models/message_model.dart';
import 'package:finishd/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({super.key, required this.chatId, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _markAsRead();
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
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _markAsRead() {
    _chatService.markMessagesAsRead(widget.chatId, _currentUserId);
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUserId,
      receiverId: widget.otherUser.uid,
      text: _messageController.text.trim(),
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // List is reversed, so 0 is the bottom
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // WhatsApp background color
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 2, 83, 22), // WhatsApp dark green
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUser.profileImage.isNotEmpty
                  ? NetworkImage(widget.otherUser.profileImage)
                  : null,
              backgroundColor: Colors.grey[300],
              child: widget.otherUser.profileImage.isEmpty
                  ? Text(
                      widget.otherUser.username[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUser.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
         
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hi! 👋',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;

                    return MessageBubble(
                      text: message.text,
                      isMe: isMe,
                      timestamp: message.timestamp,
                      isRead: message.isRead,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
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
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: const BoxDecoration(color: Color(0xFFF0F0F0)),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25.0),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _showEmojiPicker
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                      onPressed: _toggleEmojiPicker,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                   
                    const SizedBox(width: 4),
                    
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color.fromARGB(255, 2, 83, 22),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 22),
                onPressed: _sendMessage,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
