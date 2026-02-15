import 'package:supabase_flutter/supabase_flutter.dart';
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
  final SupabaseClient _supabase = Supabase.instance.client;
  final UserService _userService = UserService();

  /// Fetches and aggregates social signals from friends' activity
  /// Optimized for Supabase: Single query to user_titles
  Future<Map<String, SocialSignal>> fetchSocialSignals(
    String currentUid,
  ) async {
    try {
      // 1. Get following list
      final followingUids = await _userService.getFollowingCached(currentUid);
      if (followingUids.isEmpty) return {};

      // Limit to top 50 friends for performance
      final limitedUids = followingUids.take(50).toList();

      final Map<String, SocialSignal> signals = {};

      // 2. Fetch all user_titles for these friends
      // WHERE user_id IN (uids)
      final response = await _supabase
          .from('user_titles')
          .select()
          .filter('user_id', 'in', limitedUids);

      // 3. Process results
      for (final row in response) {
        final friendUid = row['user_id'] as String;
        final titleId = row['title_id'] as String;
        final status = row['status'] as String?;
        final isFav = row['is_favorite'] as bool? ?? false;
        final rating = row['rating'] as int?;

        // Init signal
        final signal = signals.putIfAbsent(
          titleId,
          () => SocialSignal(
            friendsWatching: [],
            friendsLiked: [],
            friendsFinished: [],
          ),
        );

        // Add to buckets
        if (status == 'watching') {
          signal.friendsWatching.add(friendUid);
        }

        if (status == 'finished') {
          signal.friendsFinished.add(friendUid);
        }

        if (isFav || (rating != null && rating >= 4)) {
          if (!signal.friendsLiked.contains(friendUid)) {
            signal.friendsLiked.add(friendUid);
          }
        }
      }

      return signals;
    } catch (e) {
      print('Error fetching social signals: $e');
      return {};
    }
  }
}
