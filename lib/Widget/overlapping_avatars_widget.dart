import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Widget/user_avatar.dart';
import 'package:flutter/material.dart';

/// Widget that displays overlapping profile avatars
/// Shows up to 3 avatars with overlap, and a "+N" badge if there are more
class OverlappingAvatarsWidget extends StatelessWidget {
  final List<String?> imageUrls; // List of profile image URLs
  final VoidCallback? onTap;
  final double avatarSize;
  final double overlapOffset;

  const OverlappingAvatarsWidget({
    super.key,
    required this.imageUrls,
    this.onTap,
    this.avatarSize = 30,
    this.overlapOffset = 20,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount = imageUrls.length > 3 ? 3 : imageUrls.length;
    final remainingCount = imageUrls.length - 3;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: (displayCount * overlapOffset) + avatarSize,
        height: avatarSize,
        child: Stack(
          children: [
            // Display up to 3 avatars
            for (int i = 0; i < displayCount; i++)
              Positioned(
                left: i * overlapOffset,
                child: _buildAvatar(
                  context,
                  imageUrls[i],
                  showBadge: i == 2 && remainingCount > 0,
                  badgeCount: remainingCount,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    String? imageUrl, {
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          UserAvatar(
            radius: avatarSize / 2,
            profileImageUrl: imageUrl,
            userId: imageUrl ?? 'anonymous', // Minimal requirement for deterministic color
          ),
          // Badge overlay if there are more avatars
          if (showBadge)
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.6)
                    : Colors.white.withOpacity(0.4),
              ),
              child: Center(
                child: Text(
                  '+$badgeCount',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
