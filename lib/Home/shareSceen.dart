import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'share_to_friends_sheet.dart';

/// Shows a share bottom sheet with two sections:
/// 1. Friends section - tap to share via in-app chat
/// 2. External apps - SMS, Email, WhatsApp, etc.
void showVideoShareSheet(
  BuildContext context, {
  required String videoId,
  required String videoTitle,
  required String videoThumbnail,
  required String videoChannel,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,

    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _ShareSheetContent(
          videoId: videoId,
          videoTitle: videoTitle,
          videoThumbnail: videoThumbnail,
          videoChannel: videoChannel,
          scrollController: scrollController,
        ),
      ),
    ),
  );
}

/// Legacy function for backward compatibility (no video data)
void showShareBottomSheet(BuildContext context) {
  showVideoShareSheet(
    context,
    videoId: '',
    videoTitle: '',
    videoThumbnail: '',
    videoChannel: '',
  );
}

class _ShareSheetContent extends StatelessWidget {
  final String videoId;
  final String videoTitle;
  final String videoThumbnail;
  final String videoChannel;
  final ScrollController scrollController;

  const _ShareSheetContent({
    required this.videoId,
    required this.videoTitle,
    required this.videoThumbnail,
    required this.videoChannel,
    required this.scrollController,
  });

  /// Detect if videoId is a UUID (creator video) vs YouTube ID
  bool get _isCreatorVideo => videoId.length > 20 && videoId.contains('-');

  String get _shareUrl => videoId.isNotEmpty
      ? (_isCreatorVideo
            ? 'https://finishd.app/video/$videoId' // Deep link for creator videos
            : 'https://youtu.be/$videoId') // YouTube short URL
      : 'Check out FINISHD app!';

  String get _shareText => videoTitle.isNotEmpty
      ? '🎬 $videoTitle\n\nWatch on FINISHD: $_shareUrl'
      : 'Check out FINISHD app!';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Share",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Friends section
        if (videoId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                ShareToFriendsSheet.show(
                  context,
                  videoId: videoId,
                  videoTitle: videoTitle,
                  videoThumbnail: videoThumbnail,
                  videoChannel: videoChannel,
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A8927).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1A8927).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A8927),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send to Friends',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Share directly in FINISHD chat',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        // External share options
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Share via",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildShareOption(
                context,
                Icons.copy,
                "Copy Link",
                Colors.grey[700]!,
                () => _copyLink(context),
              ),
              _buildShareOption(
                context,
                Icons.share,
                "More",
                Colors.blue,
                () => _shareExternal(context),
              ),
              _buildShareOption(
                context,
                Icons.message,
                "SMS",
                Colors.green,
                () => _shareVia(context, 'sms'),
              ),
              _buildShareOption(
                context,
                Icons.email,
                "Email",
                Colors.red,
                () => _shareVia(context, 'email'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _copyLink(BuildContext context) {
    // Copy to clipboard
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareExternal(BuildContext context) {
    Navigator.pop(context);
    Share.share(_shareText, subject: videoTitle);
  }

  void _shareVia(BuildContext context, String method) {
    Navigator.pop(context);
    Share.share(_shareText, subject: videoTitle);
  }

  Widget _buildShareOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
