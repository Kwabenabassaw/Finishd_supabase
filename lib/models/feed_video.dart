class FeedVideo {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String channelName;

  FeedVideo({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.channelName,
  });

  factory FeedVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'];
    return FeedVideo(
      videoId: json['id']['videoId'] ?? '',
      title: snippet['title'] ?? '',
      thumbnailUrl: snippet['thumbnails']['high']['url'] ?? '',
      channelName: snippet['channelTitle'] ?? '',
    );
  }
}
