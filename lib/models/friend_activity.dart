class FriendActivity {
  final String itemId;
  final String friendUid;
  final String friendName;
  final String avatarUrl;
  final String status;
  final int timestamp;

  FriendActivity({
    required this.itemId,
    required this.friendUid,
    required this.friendName,
    required this.avatarUrl,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'friendUid': friendUid,
      'friendName': friendName,
      'avatarUrl': avatarUrl,
      'status': status,
      'timestamp': timestamp,
    };
  }

  factory FriendActivity.fromMap(Map<String, dynamic> map) {
    return FriendActivity(
      itemId: map['itemId'],
      friendUid: map['friendUid'],
      friendName: map['friendName'],
      avatarUrl: map['avatarUrl'],
      status: map['status'],
      timestamp: map['timestamp'],
    );
  }
}
