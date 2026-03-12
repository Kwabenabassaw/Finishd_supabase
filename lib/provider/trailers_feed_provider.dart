import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trailer_item.dart';
import '../services/kinocheck_service.dart';
import '../services/user_preferences_service.dart';
import '../tmbd/fetchDiscover.dart';
import '../tmbd/fetch_trialler.dart';

/// Provider for the Trailers Tab (Discovery Mode)
/// Fetches trailers from Kinocheck API and categorizes them, 
/// including personalized genre-based sections.
class TrailersFeedProvider extends ChangeNotifier {
  final KinocheckService _kinocheckService = KinocheckService();
  final UserPreferencesService _prefsService = UserPreferencesService();
  final Fetchdiscover _fetchDiscover = Fetchdiscover();
  final TvService _tvService = TvService();

  List<TrailerItem> _trending = [];
  List<TrailerItem> _discover = [];
  List<TrailerItem> _newMovies = [];
  List<TrailerItem> _newTvShows = [];
  List<TrailerItem> _lastest = [];
  Map<String, List<TrailerItem>> _genreSections = {};

  bool _isLoading = false;
  String? _error;

  List<TrailerItem> get trending => _trending;
  List<TrailerItem> get discover => _discover;
  List<TrailerItem> get newMovies => _newMovies;
  List<TrailerItem> get newTvShows => _newTvShows;
  List<TrailerItem> get lastest => _lastest;
  Map<String, List<TrailerItem>> get genreSections => _genreSections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    if (_trending.isNotEmpty || _isLoading) return;
    await refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Fetch standard categories from Kinocheck
      final page1 = await _kinocheckService.getTrailers(page: 1);
      final page2 = await _kinocheckService.getTrailers(page: 2);
      final page3 = await _kinocheckService.getTrailers(page: 3);
      final page4 = await _kinocheckService.getTrailers(page: 4);
      final lastest = await _kinocheckService.Trailerstoday();

      final List<TrailerItem> allTrailers = [...page1, ...page2, ...page3,...page4,...lastest];

      // Dedup items
      final uniqueTrailers = <String, TrailerItem>{};
      for (var t in allTrailers) {
        uniqueTrailers[t.id] = t;
      }
      final dedupedList = uniqueTrailers.values.toList();

      // Categorize
      _trending = page1.toList();
      _lastest = lastest.toList();

      _discover = [...page2,...page4];
      _discover.shuffle();

      _newMovies = dedupedList.where((t) => t.mediaType == 'movie').toList();
      _newTvShows = dedupedList.where((t) => t.mediaType == 'show').toList();

      // Ensure lists aren't entirely empty if some categories are missing
      if (_newMovies.isEmpty) _newMovies = _trending;
      if (_newTvShows.isEmpty) _newTvShows = _discover;

      // 2. Fetch personalized genres
      await _fetchGenreSections();
    } catch (e) {
      _error = e.toString();
      debugPrint('[TrailersFeed] Error refreshing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchGenreSections() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final prefs = await _prefsService.getUserPreferences(userId);
      if (prefs == null || prefs.selectedGenreIds.isEmpty) return;

      final Map<String, List<TrailerItem>> sections = {};
      
      // Limit to top 3 genres for performance
      final genresToFetch = prefs.selectedGenreIds.take(3).toList();
      final namesToFetch = prefs.selectedGenres.take(3).toList();

      // Fetch in parallel
      final futures = <Future<List<TrailerItem>>>[];
      for (int i = 0; i < genresToFetch.length; i++) {
        futures.add(_fetchTrailersForGenre(genresToFetch[i]));
      }

      final results = await Future.wait(futures);
      for (int i = 0; i < results.length; i++) {
         if (results[i].isNotEmpty) {
           sections[namesToFetch[i]] = results[i];
         }
      }

      _genreSections = sections;
    } catch (e) {
      debugPrint('[TrailersFeed] Error fetching genre sections: $e');
    }
  }

  Future<List<TrailerItem>> _fetchTrailersForGenre(int genreId) async {
    try {
      // Fetch popular content by genre (using a default providerId 8 - Netflix for relevance)
      final mediaItems = await _fetchDiscover.fetchByGenre(8, genreId); 
      
      final List<TrailerItem> trailers = [];
      // Resolve first 5 items to keep it snappy
      final itemsToResolve = mediaItems.take(5).toList();
      
      for (var item in itemsToResolve) {
        String? key;
        if (item.mediaType == 'movie' || item.mediaType == 'unknown') {
          key = await _tvService.getMovieTrailerKey(item.id.toString());
        } else {
          key = await _tvService.getTVShowTrailerKey(item.id.toString());
        }
        
        if (key != null) {
          trailers.add(TrailerItem(
            id: item.id.toString(),
            title: item.title,
            posterUrl: item.posterPath.isNotEmpty ? 'https://image.tmdb.org/t/p/w500${item.posterPath}' : '',
            backdropUrl: item.backdropPath.isNotEmpty ? 'https://image.tmdb.org/t/p/original${item.backdropPath}' : '',
            description: item.overview,
            youtubeKey: key,
            voteAverage: item.voteAverage,
            mediaType: item.mediaType,
            releaseDate: DateTime.tryParse(item.releaseDate),
          ));
        }
      }
      return trailers;
    } catch (e) {
      debugPrint('Error fetching trailers for genre $genreId: $e');
      return [];
    }
  }

  // Backwards compatibility for the infinite scroll grid (if needed elsewhere)
  List<TrailerItem> get trailers => _trending;
  bool get hasMore => false;
  Future<void> fetchMore() async {}
}
