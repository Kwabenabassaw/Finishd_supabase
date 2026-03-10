import 'package:hive/hive.dart';

// Actually, since we're writing adapters manually, we can define the classes directly and their adapters in a separate file or inline.

class ShowRelease {
  final String title;
  final int? season;
  final int? episode;
  final String date;
  final int? tmdbId;
  final bool isMovie;

  ShowRelease({
    required this.title,
    this.season,
    this.episode,
    required this.date,
    this.tmdbId,
    this.isMovie = false,
  });

  factory ShowRelease.fromJson(Map<String, dynamic> json, {bool isMovie = false}) {
    int? tmdbId;
    if (json['ids'] != null && json['ids']['tmdb'] != null) {
      tmdbId = int.tryParse(json['ids']['tmdb'].toString());
    }

    // For movies, SIMKL API might return release_date or date. For tv, it's usually date or aired.
    String date = json['date'] ?? json['aired'] ?? json['release_date'] ?? '';

    return ShowRelease(
      title: json['title'] ?? json['movie']?['title'] ?? json['show']?['title'] ?? '',
      season: json['season'],
      episode: json['episode'],
      date: date,
      tmdbId: tmdbId,
      isMovie: isMovie,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'season': season,
      'episode': episode,
      'date': date,
      'tmdbId': tmdbId,
      'isMovie': isMovie,
    };
  }
}

class ShowReleaseAdapter extends TypeAdapter<ShowRelease> {
  @override
  final typeId = 100;

  @override
  ShowRelease read(BinaryReader reader) {
    return ShowRelease(
      title: reader.readString(),
      season: reader.read(), // int?
      episode: reader.read(), // int?
      date: reader.readString(),
      tmdbId: reader.read(), // int?
      isMovie: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, ShowRelease obj) {
    writer.writeString(obj.title);
    writer.write(obj.season);
    writer.write(obj.episode);
    writer.writeString(obj.date);
    writer.write(obj.tmdbId);
    writer.writeBool(obj.isMovie);
  }
}

class ReleaseSchedule {
  final DateTime lastFetched;
  final List<ShowRelease> shows; // Upcoming shows
  final List<ShowRelease> trendingShows;
  final List<ShowRelease> movies; // Trending movies

  ReleaseSchedule({
    required this.lastFetched,
    required this.shows,
    required this.trendingShows,
    required this.movies,
  });
}

class ReleaseScheduleAdapter extends TypeAdapter<ReleaseSchedule> {
  @override
  final typeId = 101;

  @override
  ReleaseSchedule read(BinaryReader reader) {
    // Handling backwards compatibility if the cached object didn't have trendingShows
    final lastFetchedStr = reader.readString();
    final showsList = reader.readList().cast<ShowRelease>();

    List<ShowRelease> trendingShowsList = [];
    List<ShowRelease> moviesList = [];

    // We expect at least one more list (movies)
    if (reader.availableBytes > 0) {
      // Due to the way writeList works without strict field IDs here,
      // we must read carefully. It's safer to read the remaining lists.
      final nextList = reader.readList().cast<ShowRelease>();
      if (reader.availableBytes > 0) {
        // We have three lists
        trendingShowsList = nextList;
        moviesList = reader.readList().cast<ShowRelease>();
      } else {
        // We only have two lists (old format where it was just shows and movies)
        moviesList = nextList;
        trendingShowsList = [];
      }
    }

    return ReleaseSchedule(
      lastFetched: DateTime.parse(lastFetchedStr),
      shows: showsList,
      trendingShows: trendingShowsList,
      movies: moviesList,
    );
  }

  @override
  void write(BinaryWriter writer, ReleaseSchedule obj) {
    writer.writeString(obj.lastFetched.toIso8601String());
    writer.writeList(obj.shows);
    writer.writeList(obj.trendingShows);
    writer.writeList(obj.movies);
  }
}
