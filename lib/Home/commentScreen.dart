import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
        dividerColor: Colors.transparent, // Remove default divider lines
      ),
      home: const CommentsScreen(),
    );
  }
}

// --- Model ---
class Comment {
  final String username;
  final String content;
  final String timeAgo;
  final String likes;
  final String avatarUrl;
  final int replyCount;
  final bool isVerified;

  Comment({
    required this.username,
    required this.content,
    required this.timeAgo,
    required this.likes,
    required this.avatarUrl,
    this.replyCount = 0,
    this.isVerified = false,
  });
}

// --- Main Screen ---
class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  // Mock Data derived from the image
  final List<Comment> comments = [
    Comment(
      username: 'martini_rond',
      content: 'How neatly I write the date in my book',
      timeAgo: '22h',
      likes: '8098',
      replyCount: 4,
      avatarUrl: 'https://i.pravatar.cc/150?u=martini',
    ),
    Comment(
      username: 'maxjacobson',
      content: 'Now that’s a skill very talented',
      timeAgo: '22h',
      likes: '809',
      replyCount: 1,
      avatarUrl: 'https://i.pravatar.cc/150?u=max',
    ),
    Comment(
      username: 'zackjohn',
      content: 'Doing this would make me so anxious',
      timeAgo: '22h',
      likes: '809',
      avatarUrl: 'https://i.pravatar.cc/150?u=zack',
    ),
    Comment(
      username: 'kiero_d',
      content: 'Use that on r air forces to whiten them',
      timeAgo: '21h',
      likes: '809',
      replyCount: 9,
      avatarUrl: 'https://i.pravatar.cc/150?u=kiero',
    ),
    Comment(
      username: 'mis_potter',
      content: 'Sjpuld’ve used that on his forces 😂😂',
      timeAgo: '13h',
      likes: '809',
      replyCount: 4,
      isVerified: true,
      avatarUrl: 'https://i.pravatar.cc/150?u=potter',
    ),
    Comment(
      username: 'karennne',
      content: 'No prressure',
      timeAgo: '22h',
      likes: '809',
      replyCount: 2,
      avatarUrl: 'https://i.pravatar.cc/150?u=karen',
    ),
    Comment(
      username: 'joshua_l',
      content: 'My OCD couldn’t do it',
      timeAgo: '15h',
      likes: '809',
      avatarUrl: 'https://i.pravatar.cc/150?u=joshua',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                '579 comments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black.withOpacity(0.8),
                ),
              ),
            ),

            // --- Comment List ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  return CommentItem(comment: comments[index]);
                },
              ),
            ),

            // --- Bottom Input Bar ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Add comment...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 15,
                      ),
                      cursorColor: Colors.blue,
                    ),
                  ),
                  Icon(
                    Icons.alternate_email,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade800,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.sentiment_satisfied_alt,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade800,
                    size: 24,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Comment Item Widget ---
class CommentItem extends StatelessWidget {
  final Comment comment;

  const CommentItem({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: NetworkImage(comment.avatarUrl),
          ),
          const SizedBox(width: 12),

          // Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username Row
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (comment.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Colors.lightBlue,
                        size: 14,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Comment Text & Time
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, height: 1.3),
                    children: [
                      TextSpan(
                        text: comment.content,
                        style: const TextStyle(color: Colors.black),
                      ),
                      WidgetSpan(child: SizedBox(width: 8)),
                      TextSpan(
                        text: comment.timeAgo,
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),

                // View Replies Section
                if (comment.replyCount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Decorative line (optional, purely aesthetic based on common designs)
                      Container(
                        width: 20,
                        height: 1,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Text(
                        'View replies (${comment.replyCount})',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Like Button Column
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 20, color: Colors.grey),
              const SizedBox(height: 2),
              Text(
                comment.likes,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
