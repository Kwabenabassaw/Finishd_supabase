import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finishd/Model/movie_list_item.dart';
import 'package:finishd/services/social_database_helper.dart';

/// Service to manage user's movie lists in Supabase + SQLite cache
/// Replaces legacy Firestore collections (watching, watchlist, finished, favorites)
/// Uses 'user_titles' table in Supabase.
class MovieListService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SocialDatabaseHelper _dbHelper = SocialDatabaseHelper();

  // Legacy list names mapped to 'status' or 'is_favorite'
  static const String _watchingCollection = 'watching';
  static const String _watchlistCollection = 'watchlist';
  static const String _finishedCollection = 'finished';
  static const String _favoritesCollection = 'favorites';

  // ==========================================================================
  // WRITE OPERATIONS
  // ==========================================================================

  /// Add movie to "Currently Watching" list (status = watching)
  Future<void> addToWatching(String uid, MovieListItem movie) async {
    try {
      await _dbHelper.insertListItem(_watchingCollection, movie);
      await _dbHelper.removeListItem(_watchlistCollection, movie.id);

      await _supabase.from('user_titles').upsert({
        'user_id': uid,
        'title_id': movie.id,
        'media_type': movie.mediaType,
        'title': movie.title,
        'poster_path': movie.posterPath,
        'genre': movie.genre,
        'rating': movie.rating,
        'status': 'watching',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding to watching: $e');
      rethrow;
    }
  }

  /// Add movie to "Watch Later" list (status = watchlist)
  Future<void> addToWatchlist(String uid, MovieListItem movie) async {
    try {
      await _dbHelper.insertListItem(_watchlistCollection, movie);
      await _dbHelper.removeListItem(_watchingCollection, movie.id);

      await _supabase.from('user_titles').upsert({
        'user_id': uid,
        'title_id': movie.id,
        'media_type': movie.mediaType,
        'title': movie.title,
        'poster_path': movie.posterPath,
        'genre': movie.genre,
        'status': 'watchlist',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding to watchlist: $e');
      rethrow;
    }
  }

  /// Add movie to "Finished" list (status = finished)
  Future<void> addToFinished(String uid, MovieListItem movie) async {
    try {
      await _dbHelper.insertListItem(_finishedCollection, movie);
      await _dbHelper.removeListItem(_watchingCollection, movie.id);
      await _dbHelper.removeListItem(_watchlistCollection, movie.id);

      await _supabase.from('user_titles').upsert({
        'user_id': uid,
        'title_id': movie.id,
        'media_type': movie.mediaType,
        'title': movie.title,
        'poster_path': movie.posterPath,
        'genre': movie.genre,
        'status': 'finished',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error adding to finished: $e');
      rethrow;
    }
  }

  /// Toggle Favorite (is_favorite boolean)
  Future<void> toggleFavorite(String uid, MovieListItem movie) async {
    try {
      final current = await _supabase
          .from('user_titles')
          .select('is_favorite')
          .match({
            'user_id': uid,
            'title_id': movie.id,
            'media_type': movie.mediaType,
          })
          .maybeSingle();

      final bool isFav = current != null
          ? (current['is_favorite'] ?? false)
          : false;
      final bool newFav = !isFav;

      if (newFav) {
        await _dbHelper.insertListItem(_favoritesCollection, movie);
      } else {
        await _dbHelper.removeListItem(_favoritesCollection, movie.id);
      }

      await _supabase.from('user_titles').upsert({
        'user_id': uid,
        'title_id': movie.id,
        'media_type': movie.mediaType,
        'title': movie.title,
        'poster_path': movie.posterPath,
        'genre': movie.genre,
        'is_favorite': newFav,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Remove movie from a specific list (clear status)
  Future<void> removeFromList(
    String uid,
    String movieId,
    String listType,
  ) async {
    try {
      await _dbHelper.removeListItem(listType, movieId);

      if (listType == _favoritesCollection) {
        await _supabase
            .from('user_titles')
            .update({'is_favorite': false})
            .match({'user_id': uid, 'title_id': movieId});
      } else {
        await _supabase.from('user_titles').update({'status': null}).match({
          'user_id': uid,
          'title_id': movieId,
        });
      }
    } catch (e) {
      print('Error removing from $listType: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // READ OPERATIONS
  // ==========================================================================

  Future<List<MovieListItem>> getMoviesFromList(
    String uid,
    String listType,
  ) async {
    try {
      dynamic response;
      if (listType == _favoritesCollection) {
        response = await _supabase
            .from('user_titles')
            .select()
            .eq('user_id', uid)
            .eq('is_favorite', true)
            .order('updated_at', ascending: false);
      } else {
        response = await _supabase
            .from('user_titles')
            .select()
            .eq('user_id', uid)
            .eq('status', listType)
            .order('updated_at', ascending: false);
      }
      return (response as List)
          .map((data) => MovieListItem.fromSupabase(data))
          .toList();
    } catch (e) {
      print('Error getting movies from $listType: $e');
      return [];
    }
  }

  Future<List<MovieListItem>> getMoviesFromListLocal(String listType) async {
    return await _dbHelper.getListItems(listType);
  }

  Stream<List<MovieListItem>> streamMoviesFromListHybrid(
    String uid,
    String listType,
  ) {
    StreamController<List<MovieListItem>>? controller;
    StreamSubscription? supabaseSub;

    controller = StreamController<List<MovieListItem>>(
      onListen: () async {
        // 1. Yield local data immediately
        try {
          final localMovies = await _dbHelper.getListItems(listType);
          if (controller != null && !controller.isClosed) {
            controller.add(localMovies);
          }
        } catch (e) {
          print('Error loading local cache for $listType: $e');
        }

        // 2. Subscribe to Supabase Realtime updates
        // Use streamMoviesFromList for the filtered stream
        supabaseSub = streamMoviesFromList(uid, listType).listen(
          (movies) async {
            // Update local cache
            await _dbHelper.syncList(listType, movies);
            // Emit fresh data
            if (controller != null && !controller.isClosed) {
              controller.add(movies);
            }
          },
          onError: (e) {
            print('Error in hybrid stream for $listType: $e');
            if (controller != null && !controller.isClosed) {
              controller.addError(e);
            }
          },
        );
      },
      onCancel: () async {
        await supabaseSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Standard stream (for "other users" or specific list usage)
  Stream<List<MovieListItem>> streamMoviesFromList(
    String uid,
    String listType,
  ) {
    if (listType == _favoritesCollection) {
      return _supabase
          .from('user_titles')
          .stream(primaryKey: ['user_id', 'title_id', 'media_type'])
          .eq('user_id', uid) // Explicitly filter by user_id
          .map((data) {
            final filtered = data
                .where((json) => json['is_favorite'] == true)
                .map((json) => MovieListItem.fromSupabase(json))
                .toList();
            // Sort in Dart
            filtered.sort(
              (a, b) => (b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            );
            return filtered;
          });
    } else {
      return _supabase
          .from('user_titles')
          .stream(primaryKey: ['user_id', 'title_id', 'media_type'])
          .eq('user_id', uid)
          .map((data) {
            final filtered = data
                .where((json) => json['status'] == listType)
                .map((json) => MovieListItem.fromSupabase(json))
                .toList();
            // Sort in Dart
            filtered.sort(
              (a, b) => (b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            );
            return filtered;
          });
    }
  }

  Future<Map<String, bool>> getMovieStatus(String uid, String movieId) async {
    try {
      final response = await _supabase
          .from('user_titles')
          .select()
          .eq('user_id', uid)
          .eq('title_id', movieId)
          .maybeSingle();

      if (response == null) {
        return {
          'watching': false,
          'watchlist': false,
          'finished': false,
          'favorites': false,
        };
      }

      final status = response['status'];
      final isFav = response['is_favorite'] ?? false;

      return {
        'watching': status == 'watching',
        'watchlist': status == 'watchlist',
        'finished': status == 'finished',
        'favorites': isFav,
      };
    } catch (e) {
      return {
        'watching': false,
        'watchlist': false,
        'finished': false,
        'favorites': false,
      };
    }
  }

  /// Standard stream (for compatibility with ProfileScreen)
  // Direct stream from Supabase for simplicity in profile UI
  /// Optimized stream that fetches ALL user titles in one connection
  /// to avoid hitting Realtime connection limits.
  /// Returns a stream of the full list, which ProfileScreen can then filter.
  Stream<List<MovieListItem>> streamAllUserTitlesHybrid(String uid) {
    StreamController<List<MovieListItem>>? controller;
    StreamSubscription? supabaseSub;

    controller = StreamController<List<MovieListItem>>(
      onListen: () async {
        // 1. Yield local data (all lists merged)
        try {
          final watching = await _dbHelper.getListItems(_watchingCollection);
          final watchlist = await _dbHelper.getListItems(_watchlistCollection);
          final finished = await _dbHelper.getListItems(_finishedCollection);
          final favorites = await _dbHelper.getListItems(_favoritesCollection);

          final allLocal = [
            ...watching,
            ...watchlist,
            ...finished,
            ...favorites,
          ];
          // Deduplicate by ID just in case
          final uniqueLocal = {
            for (var item in allLocal) item.id: item,
          }.values.toList();

          if (controller != null && !controller.isClosed) {
            controller.add(uniqueLocal);
          }
        } catch (e) {
          print('Error loading local cache for all titles: $e');
        }

        // 2. Subscribe to Supabase Realtime updates (SINGLE CONNECTION)
        try {
          supabaseSub = _supabase
              .from('user_titles')
              .stream(primaryKey: ['user_id', 'title_id', 'media_type'])
              .eq('user_id', uid)
              .map(
                (data) => data
                    .map((json) => MovieListItem.fromSupabase(json))
                    .toList(),
              )
              .listen(
                (allMovies) async {
                  // Sync EVERYTHING to local DB
                  // Note: Ideally we'd replace the tables, but syncList matches by type.
                  // So we classify them here.

                  final watching = allMovies
                      .where((m) => m.status == 'watching')
                      .toList();
                  final watchlist = allMovies
                      .where((m) => m.status == 'watchlist')
                      .toList();
                  final finished = allMovies
                      .where((m) => m.status == 'finished')
                      .toList();
                  final favorites = allMovies
                      .where((m) => m.isFavorite)
                      .toList();

                  await _dbHelper.syncList(_watchingCollection, watching);
                  await _dbHelper.syncList(_watchlistCollection, watchlist);
                  await _dbHelper.syncList(_finishedCollection, finished);
                  await _dbHelper.syncList(_favoritesCollection, favorites);

                  // Emit fresh data
                  if (controller != null && !controller.isClosed) {
                    controller.add(allMovies);
                  }
                },
                onError: (e) {
                  print('Error in global user titles stream: $e');
                  // Don't crash the controller, just log.
                  // The local data is already shown.
                },
              );
        } catch (e) {
          print('Error setting up stream: $e');
        }
      },
      onCancel: () async {
        await supabaseSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Force refresh a list
  Future<List<MovieListItem>> refreshList(String uid, String listType) async {
    print('🔄 [List] Force refreshing $listType for $uid');
    final movies = await getMoviesFromList(uid, listType);
    await _dbHelper.syncList(listType, movies);
    return movies;
  }
}
