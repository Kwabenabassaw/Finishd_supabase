class FeedVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelName;
  final String description;

  FeedVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelName,
    this.description = '',
  });

  /// Factory to create from YouTube API JSON
  factory FeedVideo.fromJson(Map<String, dynamic> json) {
    // Handle both direct API response and Firestore cached data
    if (json.containsKey('snippet')) {
      // YouTube API structure
      final snippet = json['snippet'];
      final idData = json['id'];
      final videoId = idData is Map
          ? (idData['videoId'] ?? '')
          : (idData ?? '');

      return FeedVideo(
        videoId: videoId,
        title: snippet['title'] ?? '',
        thumbnailUrl: snippet['thumbnails']?['high']?['url'] ?? '',
        channelName: snippet['channelTitle'] ?? '',
        description: snippet['description'] ?? '',
      );
    } else {
      // Firestore/Local structure
      return FeedVideo(
        videoId: json['videoId'] ?? '',
        title: json['title'] ?? '',
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        channelName: json['channelName'] ?? '',
        description: json['description'] ?? '',
      );
    }
  }

  /// Convert to JSON for Firestore caching
  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'channelName': channelName,
      'description': description,
    };
  }
}
