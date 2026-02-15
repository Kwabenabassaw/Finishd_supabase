import 'package:supabase_flutter/supabase_flutter.dart';

class UserTitleRecord {
  final String userId;
  final String titleId;
  final String mediaType;
  final String title;
  final String? posterPath;
  final int? rating;
  final String? status;
  final DateTime? ratedAt;
  final bool isFavorite;

  UserTitleRecord({
    required this.userId,
    required this.titleId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.rating,
    this.status,
    this.ratedAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title_id': titleId,
      'media_type': mediaType,
      'title': title,
      'poster_path': posterPath,
      'rating': rating,
      'status': status,
      'is_favorite': isFavorite,
      'rated_at': ratedAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory UserTitleRecord.fromJson(Map<String, dynamic> data) {
    return UserTitleRecord(
      userId: data['user_id'] ?? '',
      titleId: data['title_id'] ?? '',
      mediaType: data['media_type'] ?? '',
      title: data['title'] ?? '',
      posterPath: data['poster_path'],
      rating: data['rating'],
      status: data['status'],
      isFavorite: data['is_favorite'] ?? false,
      ratedAt: data['rated_at'] != null
          ? DateTime.tryParse(data['rated_at'])
          : null,
    );
  }
}

class UserTitlesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get a user's record for a specific title
  Future<UserTitleRecord?> getUserTitle(String uid, String titleId) async {
    try {
      final response = await _supabase.from('user_titles').select().match({
        'user_id': uid,
        'title_id': titleId,
        // 'media_type': mediaType // Ideally we check this too, but for legacy compatibility we might just query by ID if unique enough or grab first
      }).maybeSingle();

      if (response != null) {
        return UserTitleRecord.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error getting user title: $e');
      return null;
    }
  }

  /// Update rating for a title
  Future<void> updateRating({
    required String uid,
    required String titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    required int rating,
  }) async {
    try {
      // Upsert: requires all PK columns (user_id, title_id, media_type)
      await _supabase.from('user_titles').upsert({
        'user_id': uid,
        'title_id': titleId,
        'media_type': mediaType,
        'title': title,
        'poster_path': posterPath,
        'rating': rating,
        'rated_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Also record in history (ML training data)
      await _supabase.from('user_ratings').insert({
        'user_id': uid,
        'title_id': titleId,
        'rating': rating,
        'source': 'app_interaction',
      });

      // Legacy sync removed - we only use Supabase now
    } catch (e) {
      print('Error updating rating: $e');
      rethrow;
    }
  }

  /// Update status (watching, watchlist, finished, etc)
  Future<void> updateStatus({
    required String uid,
    required String titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    required String status,
  }) async {
    await _supabase.from('user_titles').upsert({
      'user_id': uid,
      'title_id': titleId,
      'media_type': mediaType,
      'title': title,
      'poster_path': posterPath,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Toggle Favorite
  Future<void> toggleFavorite({
    required String uid,
    required String titleId,
    required String mediaType,
    required String title,
    String? posterPath,
    required bool isFavorite,
  }) async {
    await _supabase.from('user_titles').upsert({
      'user_id': uid,
      'title_id': titleId,
      'media_type': mediaType,
      'title': title,
      'poster_path': posterPath,
      'is_favorite': isFavorite,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Stream a user's title record
  Stream<UserTitleRecord?> streamUserTitle(String uid, String titleId) {
    return _supabase
        .from('user_titles')
        .stream(primaryKey: ['user_id', 'title_id', 'media_type'])
        .map((data) {
          final filtered = data.where(
            (json) => json['user_id'] == uid && json['title_id'] == titleId,
          );
          if (filtered.isEmpty) return null;
          return UserTitleRecord.fromJson(filtered.first);
        });
  }

  /// Get top rated titles (rating >= 4) for personalization
  Future<List<UserTitleRecord>> getTopRatedTitles(String uid) async {
    try {
      final response = await _supabase
          .from('user_titles')
          .select()
          .eq('user_id', uid)
          .gte('rating', 4)
          .order('rating', ascending: false)
          .limit(10);

      return (response as List)
          .map((data) => UserTitleRecord.fromJson(data))
          .toList();
    } catch (e) {
      print('Error getting top rated titles: $e');
      return [];
    }
  }
}
