import 'package:flutter/foundation.dart';
import '../models/trailer_item.dart';
import '../services/kinocheck_service.dart';

/// Provider for the Trailers Tab (Discovery Mode)
/// Fetches trailers from Kinocheck API and categorizes them.
class TrailersFeedProvider extends ChangeNotifier {
  final KinocheckService _kinocheckService = KinocheckService();

  List<TrailerItem> _trending = [];
  List<TrailerItem> _discover = [];
  List<TrailerItem> _newMovies = [];
  List<TrailerItem> _newTvShows = [];
  List<TrailerItem> _lastest = [];

  bool _isLoading = false;
  String? _error;

  List<TrailerItem> get trending => _trending;
  List<TrailerItem> get discover => _discover;
  List<TrailerItem> get newMovies => _newMovies;
  List<TrailerItem> get newTvShows => _newTvShows;
  List<TrailerItem> get lastest => _lastest;
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
      // Fetch 3 pages to get a good mix of data
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
    } catch (e) {
      _error = e.toString();
      debugPrint('[TrailersFeed] Error refreshing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Backwards compatibility for the infinite scroll grid (if needed elsewhere)
  List<TrailerItem> get trailers => _trending;
  bool get hasMore => false;
  Future<void> fetchMore() async {}
}
