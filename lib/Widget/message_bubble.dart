import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Timestamp timestamp;
  final bool isRead;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.timestamp,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('hh:mm a').format(timestamp.toDate());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(8),
            topRight: const Radius.circular(8),
            bottomLeft: isMe
                ? const Radius.circular(8)
                : const Radius.circular(0),
            bottomRight: isMe
                ? const Radius.circular(0)
                : const Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[ const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: isRead ? const Color(0xFF34B7F1) : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
