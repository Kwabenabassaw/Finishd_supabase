import 'package:flutter/material.dart';
import 'package:finishd/Model/comment_data.dart';

/// Individual comment item widget
///
/// Displays user avatar, name, comment text, timestamp,
/// and delete option for the comment owner.
class CommentItem extends StatelessWidget {
  final CommentData comment;
  final String currentUserId;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  const CommentItem({
    super.key,
    required this.comment,
    required this.currentUserId,
    this.onDelete,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = comment.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage: comment.userAvatar != null
                ? NetworkImage(comment.userAvatar!)
                : null,
            child: comment.userAvatar == null
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and timestamp row
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.relativeTime,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Action buttons
                Row(
                  children: [
                    // Reply button (future feature)
                    // GestureDetector(
                    //   onTap: onReply,
                    //   child: Text(
                    //     'Reply',
                    //     style: TextStyle(
                    //       fontSize: 12,
                    //       color: Colors.grey[400],
                    //       fontWeight: FontWeight.w500,
                    //     ),
                    //   ),
                    // ),

                    // Delete button (only for owner)
                    if (isOwner && onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 14,
                              color: Colors.red[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loading placeholder for comments
class CommentItemSkeleton extends StatelessWidget {
  const CommentItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar skeleton
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
