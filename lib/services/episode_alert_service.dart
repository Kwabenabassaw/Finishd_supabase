import 'package:finishd/services/api_client.dart';

/// Service for checking new episodes from the backend API
class EpisodeAlertService {
  final ApiClient _apiClient = ApiClient();

  /// Check for new episodes of shows the user is watching
  Future<List<EpisodeAlert>> checkNewEpisodes() async {
    try {
      final alerts = await _apiClient.checkNewEpisodes();
      return alerts.map((a) => EpisodeAlert.fromJson(a)).toList();
    } catch (e) {
      print('❌ Error checking new episodes: $e');
      return [];
    }
  }

  /// Get upcoming episodes for the next N days
  Future<List<UpcomingEpisode>> getUpcomingEpisodes({int days = 7}) async {
    try {
      final upcoming = await _apiClient.getUpcomingEpisodes(days: days);
      return upcoming.map((u) => UpcomingEpisode.fromJson(u)).toList();
    } catch (e) {
      print('❌ Error fetching upcoming episodes: $e');
      return [];
    }
  }

  /// Get TV notifications from the new shows subcollection
  Future<List<TVNotification>> getTVNotifications() async {
    try {
      final notifications = await _apiClient.getTVNotifications();
      return notifications.map((n) => TVNotification.fromJson(n)).toList();
    } catch (e) {
      print('❌ Error fetching TV notifications: $e');
      return [];
    }
  }

  /// Get recommended shows based on watching history
  Future<List<RecommendedShow>> getRecommendations() async {
    try {
      final recs = await _apiClient.getRecommendations();
      return recs.map((r) => RecommendedShow.fromJson(r)).toList();
    } catch (e) {
      print('❌ Error fetching recommendations: $e');
      return [];
    }
  }
}

/// Model for episode alert
class EpisodeAlert {
  final int showId;
  final String showName;
  final String? showPosterPath;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeName;
  final String? airDate;
  final String overview;
  final String? stillPath;

  EpisodeAlert({
    required this.showId,
    required this.showName,
    this.showPosterPath,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeName,
    this.airDate,
    required this.overview,
    this.stillPath,
  });

  factory EpisodeAlert.fromJson(Map<String, dynamic> json) {
    return EpisodeAlert(
      showId: json['showId'] ?? 0,
      showName: json['showName'] ?? '',
      showPosterPath: json['showPosterPath'],
      seasonNumber: json['seasonNumber'] ?? 0,
      episodeNumber: json['episodeNumber'] ?? 0,
      episodeName: json['episodeName'] ?? '',
      airDate: json['airDate'],
      overview: json['overview'] ?? '',
      stillPath: json['stillPath'],
    );
  }

  String get posterUrl => showPosterPath != null
      ? 'https://image.tmdb.org/t/p/w500$showPosterPath'
      : '';

  String get stillUrl =>
      stillPath != null ? 'https://image.tmdb.org/t/p/w500$stillPath' : '';

  String get episodeLabel => 'S$seasonNumber E$episodeNumber';
}

/// Model for upcoming episode
class UpcomingEpisode {
  final int showId;
  final String showName;
  final String? showPosterPath;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeName;
  final String airDate;
  final int daysUntil;

  UpcomingEpisode({
    required this.showId,
    required this.showName,
    this.showPosterPath,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeName,
    required this.airDate,
    required this.daysUntil,
  });

  factory UpcomingEpisode.fromJson(Map<String, dynamic> json) {
    return UpcomingEpisode(
      showId: json['showId'] ?? 0,
      showName: json['showName'] ?? '',
      showPosterPath: json['showPosterPath'],
      seasonNumber: json['seasonNumber'] ?? 0,
      episodeNumber: json['episodeNumber'] ?? 0,
      episodeName: json['episodeName'] ?? '',
      airDate: json['airDate'] ?? '',
      daysUntil: json['daysUntil'] ?? 0,
    );
  }

  String get posterUrl => showPosterPath != null
      ? 'https://image.tmdb.org/t/p/w500$showPosterPath'
      : '';

  String get episodeLabel => 'S$seasonNumber E$episodeNumber';

  String get daysUntilLabel {
    if (daysUntil == 0) return 'Today';
    if (daysUntil == 1) return 'Tomorrow';
    return 'In $daysUntil days';
  }
}

/// Model for TV notification (new structure)
class TVNotification {
  final String id;
  final String title;
  final int tmdbId;
  final String? poster;
  final String type; // new_episode, recommended, trending_digest
  final int? season;
  final int? episode;
  final String? airDate;
  final String? message;
  final bool isRead;
  final DateTime? createdAt;

  TVNotification({
    required this.id,
    required this.title,
    required this.tmdbId,
    this.poster,
    required this.type,
    this.season,
    this.episode,
    this.airDate,
    this.message,
    required this.isRead,
    this.createdAt,
  });

  factory TVNotification.fromJson(Map<String, dynamic> json) {
    return TVNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      tmdbId: json['tmdb_id'] ?? 0,
      poster: json['poster'],
      type: json['type'] ?? 'new_episode',
      season: json['season'],
      episode: json['episode'],
      airDate: json['air_date'],
      message: json['message'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['created_at'])
          : null,
    );
  }

  String get posterUrl =>
      poster != null ? 'https://image.tmdb.org/t/p/w500$poster' : '';

  String get episodeLabel => season != null && episode != null
      ? 'S${season!.toString().padLeft(2, '0')}E${episode!.toString().padLeft(2, '0')}'
      : '';

  bool get isNewEpisode => type == 'new_episode';
  bool get isRecommended => type == 'recommended';
  bool get isTrendingDigest => type == 'trending_digest';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'tmdb_id': tmdbId,
    'poster': poster,
    'type': type,
    'season': season,
    'episode': episode,
    'air_date': airDate,
    'message': message,
    'is_read': isRead,
    'created_at': createdAt?.millisecondsSinceEpoch,
  };
}

/// Model for recommended show
class RecommendedShow {
  final int id;
  final String name;
  final String? posterPath;
  final double score;
  final String reason;
  final bool hasNewEpisode;
  final bool isTrending;

  RecommendedShow({
    required this.id,
    required this.name,
    this.posterPath,
    required this.score,
    required this.reason,
    required this.hasNewEpisode,
    required this.isTrending,
  });

  factory RecommendedShow.fromJson(Map<String, dynamic> json) {
    final show = json['show'] ?? {};
    return RecommendedShow(
      id: show['id'] ?? 0,
      name: show['name'] ?? show['title'] ?? '',
      posterPath: show['poster_path'],
      score: (json['score'] ?? 0).toDouble(),
      reason: json['reason'] ?? 'Recommended for you',
      hasNewEpisode: json['has_new_episode'] ?? false,
      isTrending: json['is_trending'] ?? false,
    );
  }

  String get posterUrl =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';

  Map<String, dynamic> toJson() => {
    'show': {'id': id, 'name': name, 'poster_path': posterPath},
    'score': score,
    'reason': reason,
    'has_new_episode': hasNewEpisode,
    'is_trending': isTrending,
  };
}
