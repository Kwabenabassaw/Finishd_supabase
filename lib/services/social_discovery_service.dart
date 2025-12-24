import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/services/user_service.dart';

class SocialSignal {
  final List<String> friendsWatching;
  final List<String> friendsLiked; // rating >= 4 or favorite
  final List<String> friendsFinished;

  SocialSignal({
    this.friendsWatching = const [],
    this.friendsLiked = const [],
    this.friendsFinished = const [],
  });

  int get totalCount =>
      friendsWatching.length + friendsLiked.length + friendsFinished.length;
}

class SocialDiscoveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();

  /// Fetches and aggregates social signals from friends' activity
  Future<Map<String, SocialSignal>> fetchSocialSignals(
    String currentUid,
  ) async {
    try {
      // 1. Get following list
      final followingUids = await _userService.getFollowing(currentUid);
      if (followingUids.isEmpty) return {};

      // Limit to top 50 friends for performance
      final limitedUids = followingUids.take(50).toList();

      final Map<String, SocialSignal> signals = {};

      // 2. Batch fetch friend activities
      // We'll fetch 'watching', 'finished', and 'favorites' for each friend
      // Using Future.wait for parallel execution
      final results = await Future.wait(
        limitedUids.map((friendUid) => _getFriendActivity(friendUid)),
      );

      for (var friendData in results) {
        final friendUid = friendData['uid'] as String;
        final activities =
            friendData['activities'] as Map<String, List<MovieListItem>>;

        activities.forEach((listType, items) {
          for (var item in items) {
            final signal = signals.putIfAbsent(
              item.id,
              () => SocialSignal(
                friendsWatching: [],
                friendsLiked: [],
                friendsFinished: [],
              ),
            );

            if (listType == 'watching') {
              signal.friendsWatching.add(friendUid);
            } else if (listType == 'finished') {
              signal.friendsFinished.add(friendUid);
              if (item.rating != null && item.rating! >= 4) {
                signal.friendsLiked.add(friendUid);
              }
            } else if (listType == 'favorites') {
              if (!signal.friendsLiked.contains(friendUid)) {
                signal.friendsLiked.add(friendUid);
              }
            } else if (listType == 'user_titles') {
              if (item.rating != null && item.rating! >= 4) {
                if (!signal.friendsLiked.contains(friendUid)) {
                  signal.friendsLiked.add(friendUid);
                }
              }
            }
          }
        });
      }

      return signals;
    } catch (e) {
      print('Error fetching social signals: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getFriendActivity(String friendUid) async {
    final lists = ['watching', 'finished', 'favorites', 'user_titles'];
    final Map<String, List<MovieListItem>> activities = {};

    final results = await Future.wait(
      lists.map(
        (list) => _firestore
            .collection('users')
            .doc(friendUid)
            .collection(list)
            .get(),
      ),
    );

    for (int i = 0; i < lists.length; i++) {
      final listName = lists[i];
      activities[listName] = results[i].docs.map((doc) {
        if (listName == 'user_titles') {
          final data = doc.data();
          return MovieListItem(
            id: data['titleId'] ?? doc.id,
            title: data['title'] ?? '',
            posterPath: data['posterPath'],
            mediaType: data['mediaType'] ?? 'movie',
            rating: data['rating'] as int?,
            addedAt: DateTime.now(),
          );
        }
        return MovieListItem.fromDocument(doc);
      }).toList();
    }

    return {'uid': friendUid, 'activities': activities};
  }
}
