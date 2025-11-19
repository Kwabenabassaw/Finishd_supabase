import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/Searchdiscover.dart';

extension ResultToMediaItem on Result {
  MediaItem toMediaItem() {
    return MediaItem(
      id: id ?? 0,
      title: title ?? name ?? "No Title",
      overview: overview ?? "",
      posterPath: posterPath ?? "",
      backdropPath: backdropPath ?? "",
      voteAverage: voteAverage?.toDouble() ?? 0.0,
      mediaType: mediaType ?? "unknown",
      releaseDate:
          releaseDate?.toIso8601String() ??
          firstAirDate?.toIso8601String() ??
          "",
      genreIds: genreIds, imageUrl: '',
    );
  }
}
