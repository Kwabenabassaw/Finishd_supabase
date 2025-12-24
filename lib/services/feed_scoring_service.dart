import 'package:finishd/models/feed_item.dart';
import 'package:finishd/services/user_preferences_cache.dart';

/// Feed Scoring Service - Local Personalization for "For You" Tab
///
/// This service implements deterministic scoring for feed personalization.
/// All scoring happens locally on the device with NO network calls.
///
/// Scoring weights (as per spec):
/// - Matches preferred genre: +0.4
/// - Already watched: -0.5
/// - High popularity (>80): +0.2
/// - Not in disliked genres: +0.1
class FeedScoringService {
  static FeedScoringService? _instance;
  final UserPreferencesCache _prefsCache = UserPreferencesCache.instance;

  FeedScoringService._();

  static FeedScoringService get instance {
    _instance ??= FeedScoringService._();
    return _instance!;
  }

  /// Score a single video based on user preferences.
  ///
  /// Uses weighted genre scoring from taste profile.
  /// Higher scores = more relevant to user
  double scoreVideo(FeedItem video, UserPreferences prefs) {
    double score = 0;
    double genreScore = 0;

    // 1. Genre weights (sum of matching genre weights)
    if (video.genres != null && video.genres!.isNotEmpty) {
      if (prefs.genreWeights.isNotEmpty) {
        // Use weighted scoring from taste profile
        for (final genre in video.genres!) {
          genreScore += prefs.getGenreWeight(genre);
        }
        // Cap genre score contribution at 0.6 (max boost from genres)
        score += (genreScore > 0.6 ? 0.6 : genreScore);
      } else {
        // Fallback: binary matching with preferredGenres
        final hasPreferredGenre = video.genres!.any(
          (genre) => prefs.isPreferredGenre(genre),
        );
        if (hasPreferredGenre) {
          score += 0.4;
        }
      }

      // Penalty for disliked genres
      final hasDislikedGenre = video.genres!.any(
        (genre) => prefs.isDislikedGenre(genre),
      );
      if (hasDislikedGenre) {
        score -= 0.3;
      } else if (video.genres!.isNotEmpty) {
        // Small boost for not having disliked content
        score += 0.1;
      }
    }

    // 2. Already watched penalty (-0.5)
    if (video.tmdbId != null && prefs.hasWatched(video.tmdbId!)) {
      score -= 0.5;
    }

    // 3. Watchlist boost (+0.3)
    if (video.tmdbId != null && prefs.isInWatchlist(video.tmdbId!)) {
      score += 0.3;
    }

    // 4. Popularity boost (+0.2 if popularity > 80)
    if (video.popularity != null && video.popularity! > 80) {
      score += 0.2;
    }

    return score;
  }

  /// Rank a list of feed items by personalization score.
  ///
  /// Items with higher scores appear first.
  /// Also filters out content with disliked genres.
  List<FeedItem> rankFeed(List<FeedItem> items, UserPreferences prefs) {
    // Score all items
    final scoredItems = items.map((item) {
      return _ScoredItem(item: item, score: scoreVideo(item, prefs));
    }).toList();

    // Sort by score (descending)
    scoredItems.sort((a, b) => b.score.compareTo(a.score));

    // Debug: log top 3 item scores
    if (scoredItems.isNotEmpty) {
      final topN = scoredItems.take(3).toList();
      String debugMsg = '[Scoring] Top Items: ';
      for (var s in topN) {
        debugMsg += '${s.item.title}(${s.score.toStringAsFixed(1)}) ';
      }
      print(debugMsg);
    }

    // Optionally filter out heavily penalized items
    // (e.g., items with score < -0.3 could be hidden)
    final filtered = scoredItems.where((s) => s.score > -0.3).toList();

    return filtered.map((s) => s.item).toList();
  }

  /// Async version that fetches cached preferences automatically.
  Future<List<FeedItem>> rankFeedAsync(List<FeedItem> items) async {
    final prefs = await _prefsCache.getCached();

    if (prefs == null || !prefs.hasPreferences) {
      // No preferences = return items as-is (cold start)
      return items;
    }

    return rankFeed(items, prefs);
  }

  /// Filter out disliked genres completely.
  List<FeedItem> filterDisliked(List<FeedItem> items, UserPreferences prefs) {
    if (prefs.dislikedGenres.isEmpty) return items;

    return items.where((item) {
      if (item.genres == null || item.genres!.isEmpty) return true;
      return !item.genres!.any((g) => prefs.isDislikedGenre(g));
    }).toList();
  }

  /// Get scoring debug info (useful for development)
  Map<String, dynamic> getScoreBreakdown(
    FeedItem video,
    UserPreferences prefs,
  ) {
    final breakdown = <String, dynamic>{
      'title': video.title,
      'tmdbId': video.tmdbId,
      'genres': video.genres,
      'popularity': video.popularity,
      'scores': <String, double>{},
      'genre_weights': <String, double>{},
      'total': 0.0,
    };

    double total = 0;

    // Genre weights
    if (video.genres != null && video.genres!.isNotEmpty) {
      double genreScore = 0;
      for (final genre in video.genres!) {
        final weight = prefs.getGenreWeight(genre);
        if (weight > 0) {
          breakdown['genre_weights'][genre] = weight;
          genreScore += weight;
        }
      }
      if (genreScore > 0) {
        final cappedScore = genreScore > 0.6 ? 0.6 : genreScore;
        breakdown['scores']['genre_weights'] = cappedScore;
        total += cappedScore;
      }

      // Disliked check
      final hasDisliked = video.genres!.any((g) => prefs.isDislikedGenre(g));
      if (hasDisliked) {
        breakdown['scores']['disliked_genre'] = -0.3;
        total -= 0.3;
      } else {
        breakdown['scores']['no_disliked'] = 0.1;
        total += 0.1;
      }
    }

    // Watched penalty
    if (video.tmdbId != null && prefs.hasWatched(video.tmdbId!)) {
      breakdown['scores']['already_watched'] = -0.5;
      total -= 0.5;
    }

    // Watchlist boost
    if (video.tmdbId != null && prefs.isInWatchlist(video.tmdbId!)) {
      breakdown['scores']['in_watchlist'] = 0.3;
      total += 0.3;
    }

    // Popularity boost
    if (video.popularity != null && video.popularity! > 80) {
      breakdown['scores']['popularity_boost'] = 0.2;
      total += 0.2;
    }

    breakdown['total'] = total;
    return breakdown;
  }

  /// Generate a human-readable explanation for why this video is shown.
  /// Used for "Why am I seeing this?" UX feature.
  String? getWhyThisExplanation(FeedItem video, UserPreferences prefs) {
    final reasons = <String>[];

    // Check if in watchlist
    if (video.tmdbId != null && prefs.isInWatchlist(video.tmdbId!)) {
      reasons.add('In your watchlist');
    }

    // Check for matching genres
    if (video.genres != null && video.genres!.isNotEmpty) {
      final matchingGenres = <String>[];
      for (final genre in video.genres!) {
        if (prefs.getGenreWeight(genre) > 0.3) {
          matchingGenres.add(genre);
        }
      }
      if (matchingGenres.isNotEmpty) {
        if (matchingGenres.length == 1) {
          reasons.add('You like ${matchingGenres[0]}');
        } else {
          reasons.add('You like ${matchingGenres.take(2).join(" and ")}');
        }
      }
    }

    // Check for social context (from Following feed)
    if (video.reason != null && video.reason!.isNotEmpty) {
      reasons.add(video.reason!);
    }

    if (reasons.isEmpty) {
      return null;
    }

    return reasons.join(' • ');
  }
}

/// Internal class to hold item + score during ranking
class _ScoredItem {
  final FeedItem item;
  final double score;

  _ScoredItem({required this.item, required this.score});
}
