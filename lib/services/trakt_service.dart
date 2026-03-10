import 'package:dio/dio.dart';
import 'package:finishd/models/simkl/simkl_models.dart';
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
  Future<List<ShowRelease>> fetchTvCalendar() async {
    try {
      final now = DateTime.now().toUtc();
      final startDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final response = await _dio.get('/calendars/all/shows/$startDate/30');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) {
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
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching TV Calendar from Trakt: $e');
      }
      return [];
    }
  }
}
