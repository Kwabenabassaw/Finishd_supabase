import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget that displays overlapping profile avatars
/// Shows up to 3 avatars with overlap, and a "+N" badge if there are more
class OverlappingAvatarsWidget extends StatelessWidget {
  final List<String?> imageUrls; // List of profile image URLs
  final VoidCallback? onTap;
  final double avatarSize;
  final double overlapOffset;

  const OverlappingAvatarsWidget({
    Key? key,
    required this.imageUrls,
    this.onTap,
    this.avatarSize = 30,
    this.overlapOffset = 20,
  }) : super(key: key);

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
    String? imageUrl, {
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        children: [
          CircleAvatar(
            radius: avatarSize / 2,
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : const AssetImage('assets/noimage.jpg') as ImageProvider,
          ),
          // Badge overlay if there are more avatars
          if (showBadge)
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.6),
              ),
              child: Center(
                child: Text(
                  '+$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
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
