import 'package:dio/dio.dart';
import 'package:finishd/models/simkl/trakt_model.dart';
import 'package:finishd/config/env.dart';
import 'package:flutter/foundation.dart';

class TraktService {
  final Dio _dio;

  TraktService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.trakt.tv',
              headers: {
                'Content-Type': 'application/json',
                'trakt-api-version': '2',
                'trakt-api-key': Env.traktClientId,
              },
            ),
          );

  /// Fetch TV Calendar (returns upcoming new episodes for 30 days)
  /// Also fetches poster images from TMDB for each show.
  Future<List<ShowRelease>> fetchTvCalendar() async {
    try {
      final now = DateTime.now().toUtc();
      final startDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final response = await _dio.get('/calendars/all/shows/$startDate/30');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final List<ShowRelease> releases = data.map((json) {
          final showTitle = json['show']?['title'] ?? '';

          String date = '';
          if (json['first_aired'] != null) {
            date = json['first_aired'].toString().split('T')[0];
          }

          int? episode = json['episode']?['number'];
          int? season = json['episode']?['season'];

          int? tmdbId;
          final showIds = json['show']?['ids'];
          if (showIds != null) {
            final tmdbNode = showIds['tmdb'];
            if (tmdbNode != null) {
              tmdbId = int.tryParse(tmdbNode.toString());
            }
          }

          return ShowRelease(
            title: showTitle,
            season: season,
            episode: episode,
            date: date,
            tmdbId: tmdbId,
            isMovie: false,
          );
        }).toList();

        // Fetch poster images from TMDB for all unique tmdbIds
        return await _enrichWithPosters(releases);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching TV Calendar from Trakt: $e');
      }
      return [];
    }
  }

  /// Batch-fetch poster paths from TMDB API for a list of ShowRelease items.
  /// Uses a cache map to avoid duplicate API calls for the same show.
  Future<List<ShowRelease>> _enrichWithPosters(List<ShowRelease> releases) async {
    final tmdbApiKey = Env.tmdbApiKey;
    if (tmdbApiKey.isEmpty) return releases;

    final tmdbDio = Dio(BaseOptions(
      baseUrl: 'https://api.themoviedb.org/3',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    // Collect unique TMDB IDs to avoid duplicate calls
    final Map<int, String?> posterCache = {};
    final uniqueIds = releases
        .where((r) => r.tmdbId != null)
        .map((r) => r.tmdbId!)
        .toSet()
        .toList();

    // Fetch posters in parallel batches of 10 to avoid overwhelming the API
    for (int i = 0; i < uniqueIds.length; i += 10) {
      final batch = uniqueIds.skip(i).take(10).toList();
      await Future.wait(
        batch.map((tmdbId) async {
          try {
            final resp = await tmdbDio.get(
              '/tv/$tmdbId',
              queryParameters: {'api_key': tmdbApiKey},
            );
            if (resp.statusCode == 200 && resp.data != null) {
              posterCache[tmdbId] = resp.data['poster_path'] as String?;
            }
          } catch (e) {
            // Silently skip — show will just not have a poster
            if (kDebugMode) {
              debugPrint('Failed to fetch TMDB poster for ID $tmdbId: $e');
            }
          }
        }),
      );
    }

    // Apply poster paths to releases
    return releases.map((release) {
      if (release.tmdbId != null && posterCache.containsKey(release.tmdbId)) {
        return release.copyWith(posterPath: posterCache[release.tmdbId]);
      }
      return release;
    }).toList();
  }
}
