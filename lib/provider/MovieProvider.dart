import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/Searchdiscover.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/services/social_discovery_service.dart';

class MovieProvider extends ChangeNotifier {
  // -------------------- Movies & Shows --------------------
  List<MediaItem> _movies = [];
  List<MediaItem> _shows = [];
  List<MediaItem> _popular = [];
  List<MediaItem> _upcoming = [];
  List<MediaItem> _discover = [];
  List<MediaItem> _airingToday = [];
  List<MediaItem> _nowPlaying = [];
  List<MediaItem> _topRatedTv = [];
  Map<int, List<MediaItem>> _genreSections = {};

  // Social Signals
  Map<String, SocialSignal> _socialSignals = {};
  List<MediaItem> _friendsWatching = [];
  List<MediaItem> _popularInNetwork = [];

  // Selected list for navigation (Movies/Shows)
  List<MediaItem> _selectedList = [];
  int _selectedIndex = 0;

  // Details
  MovieDetails? _movieDetail;
  TvShowDetails? _showDetail;

  // -------------------- Search Results --------------------
  List<Result> _selectedSearchResults = [];
  int _selectedSearchIndex = 0;

  // -------------------- Genre Getters & Setters --------------------
  Map<int, List<MediaItem>> get genreSections => _genreSections;
  void setGenreSection(int genreId, List<MediaItem> items) {
    _genreSections[genreId] = items;
    notifyListeners();
  }

  void clearGenreSections() {
    _genreSections.clear();
    notifyListeners();
  }

  // -------------------- Social Getters & Setters --------------------
  Map<String, SocialSignal> get socialSignals => _socialSignals;
  List<MediaItem> get friendsWatching => _friendsWatching;
  List<MediaItem> get popularInNetwork => _popularInNetwork;

  void setSocialSignals(Map<String, SocialSignal> signals) {
    _socialSignals = signals;
    notifyListeners();
  }

  void setFriendsWatching(List<MediaItem> items) {
    _friendsWatching = items;
    notifyListeners();
  }

  void setPopularInNetwork(List<MediaItem> items) {
    _popularInNetwork = items;
    notifyListeners();
  }

  // -------------------- Movies Getters & Setters --------------------
  List<MediaItem> get topRatedTv => _topRatedTv;
  void setTopRatedTv(List<MediaItem> topRatedTv) {
    _topRatedTv = topRatedTv;
    notifyListeners();
  }

  List<MediaItem> get nowPlaying => _nowPlaying;
  void setNowPlaying(List<MediaItem> nowPlaying) {
    _nowPlaying = nowPlaying;
    notifyListeners();
  }

  List<MediaItem> get airingToday => _airingToday;
  void setAiringToday(List<MediaItem> airingToday) {
    _airingToday = airingToday;
    notifyListeners();
  }

  List<MediaItem> get movies => _movies;
  void setMovies(List<MediaItem> movies) {
    _movies = movies;
    notifyListeners();
  }

  List<MediaItem> get shows => _shows;
  void setShows(List<MediaItem> shows) {
    _shows = shows;
    notifyListeners();
  }

  List<MediaItem> get popular => _popular;
  void setPopular(List<MediaItem> popular) {
    _popular = popular;
    notifyListeners();
  }

  List<MediaItem> get upcoming => _upcoming;
  void setUpcoming(List<MediaItem> upcoming) {
    _upcoming = upcoming;
    notifyListeners();
  }

  List<MediaItem> get discover => _discover;
  void setDiscover(List<MediaItem> discover) {
    _discover = discover;
    notifyListeners();
  }

  // -------------------- Movie / Show Details --------------------
  MovieDetails? get movieDetail => _movieDetail;
  void setMovieDetail(MovieDetails details) {
    _movieDetail = details;
    notifyListeners();
  }

  TvShowDetails? get showDetail => _showDetail;
  void setShowDetail(TvShowDetails details) {
    _showDetail = details;
    notifyListeners();
  }

  void clearDetails() {
    _movieDetail = null;
    _showDetail = null;
    notifyListeners();
  }

  // -------------------- Selected MediaItem (Movies/Shows) --------------------
  void selectItem(List<MediaItem> list, int index) {
    _selectedList = list;
    _selectedIndex = index;
    notifyListeners();
  }

  MediaItem? get selectedItem =>
      _selectedList.isNotEmpty ? _selectedList[_selectedIndex] : null;

  void clearSelection() {
    _selectedList = [];
    _selectedIndex = 0;
    notifyListeners();
  }

  // -------------------- Search Result → MediaItem Converter --------------------
  MediaItem convertResultToMediaItem(Result r) {
    return MediaItem(
      id: r.id ?? 0,
      title: r.title ?? r.name ?? "",
      overview: r.overview ?? "",
      imageUrl: r.posterPath != null
          ? "https://image.tmdb.org/t/p/w500${r.posterPath}"
          : "",
      voteAverage: (r.voteAverage ?? 0).toDouble(),
      mediaType: r.mediaType ?? "movie",
      backdropPath: r.backdropPath ?? "",
      posterPath: r.posterPath ?? "",
      releaseDate:
          r.releaseDate?.toIso8601String() ??
          r.firstAirDate?.toIso8601String() ??
          "",
      genreIds: r.genreIds ?? [],
    );
  }

  Result convertMediaItemToResult(MediaItem item) {
    return Result(
      id: item.id,
      title: item.title,
      name: item.title, // For TV shows, you might store the name in title field
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      overview: item.overview,
      voteAverage: item.voteAverage,
      mediaType: item.mediaType,
      releaseDate: DateTime.tryParse(item.releaseDate),
      genreIds: item.genreIds,
      adult: null,
      originalLanguage: '',
      originalTitle: '',
      popularity: null,
      video: null,
      voteCount: null,
      originalName: '',
      firstAirDate: null,
      originCountry: [], profilePath: '',
    );
  }

  // -------------------- Search Selection as MediaItem --------------------
  MediaItem? get selectedSearchAsMediaItem {
    if (_selectedSearchResults.isEmpty) return null;
    return convertResultToMediaItem(
      _selectedSearchResults[_selectedSearchIndex],
    );
  }

  // -------------------- Search Result Selection --------------------
  void selectSearchItem(List<Result> list, int index) {
    _selectedSearchResults = list;
    _selectedSearchIndex = index;
    notifyListeners();
  }

  Result? get selectedSearchItem => _selectedSearchResults.isNotEmpty
      ? _selectedSearchResults[_selectedSearchIndex]
      : null;

  void clearSearchSelection() {
    _selectedSearchResults = [];
    _selectedSearchIndex = 0;
    notifyListeners();
  }
}
