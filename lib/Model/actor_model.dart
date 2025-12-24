import 'package:finishd/Model/trending.dart'; // For MediaItem reused in credits

class ActorModel {
  final int id;
  final String name;
  final String biography;
  final String birthday;
  final String? deathday;
  final String placeOfBirth;
  final String profilePath;
  final String knownForDepartment;
  final List<String> images;
  final Map<String, String?> externalIds;
  final List<MediaItem> cast;
  final List<MediaItem> crew;
  final ActorAwards awards;

  ActorModel({
    required this.id,
    required this.name,
    required this.biography,
    required this.birthday,
    this.deathday,
    required this.placeOfBirth,
    required this.profilePath,
    required this.knownForDepartment,
    required this.images,
    required this.externalIds,
    required this.cast,
    required this.crew,
    required this.awards,
  });

  factory ActorModel.fromJson(Map<String, dynamic> json) {
    // 1. Images
    final imagesList = <String>[];
    if (json['images'] != null && json['images']['profiles'] != null) {
      for (var img in json['images']['profiles']) {
        if (img['file_path'] != null) {
          imagesList.add(img['file_path']);
        }
      }
    }

    // 2. External IDs
    final externalIdsMap = <String, String?>{
      'imdb_id': json['external_ids']?['imdb_id'],
      'instagram_id': json['external_ids']?['instagram_id'],
      'facebook_id': json['external_ids']?['facebook_id'],
      'twitter_id': json['external_ids']?['twitter_id'],
    };

    // 3. Combined Credits (Cast/Crew)
    final castList = <MediaItem>[];
    final crewList = <MediaItem>[];

    if (json['combined_credits'] != null) {
      if (json['combined_credits']['cast'] != null) {
        for (var item in json['combined_credits']['cast']) {
          try {
            castList.add(MediaItem.fromJson(item));
          } catch (e) {
            // Skip invalid items
          }
        }
      }
      if (json['combined_credits']['crew'] != null) {
        for (var item in json['combined_credits']['crew']) {
          try {
            crewList.add(MediaItem.fromJson(item));
          } catch (e) {
            // Skip invalid items
          }
        }
      }
    }

    // Sort cast by popularity or release date if needed
    // For "Known For", we might want to sort by vote_count or popularity (if available in MediaItem, but Trending.MediaItem has voteAverage)
    // We'll handle sorting in the Provider/Service or UI helper

    return ActorModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown',
      biography: json['biography'] ?? '',
      birthday: json['birthday'] ?? '',
      deathday: json['deathday'],
      placeOfBirth: json['place_of_birth'] ?? '',
      profilePath: json['profile_path'] ?? '',
      knownForDepartment: json['known_for_department'] ?? 'Acting',
      images: imagesList,
      externalIds: externalIdsMap,
      cast: castList,
      crew: crewList,
      awards: json['awards_data'] != null
          ? ActorAwards.fromAggregatedJson(json['awards_data'])
          : ActorAwards.empty(),
    );
  }

  // Helper to get top 4 "Known For" credits
  // Sort by Vote Count first (as a proxy for impact/popularity if generic popularity is noisy),
  // OR sort by Popularity. Let's start with Popularity, then Vote Count if popularity is similar.
  // Actually, TMDB 'known_for' logic is complex, but popularity is a good heuristic.
  List<MediaItem> get knownFor {
    final seen = <int>{};
    final unique = cast.where((c) => seen.add(c.id)).toList();

    // Sort by popularity descending
    unique.sort((a, b) => b.popularity.compareTo(a.popularity));

    // Fallback: If popularity is 0, sort by vote count
    if (unique.isNotEmpty && unique.first.popularity == 0) {
      unique.sort((a, b) => b.voteCount.compareTo(a.voteCount));
    }

    return unique
        .take(10)
        .toList(); // Return top 10 to give UI more options if needed
  }

  // All filmography sorted by release date
  List<MediaItem> get allCredits {
    final seen = <int>{};
    final unique = cast.where((c) => seen.add(c.id)).toList();
    unique.sort((a, b) {
      if (a.releaseDate.isEmpty) return 1;
      if (b.releaseDate.isEmpty) return -1;
      return b.releaseDate.compareTo(a.releaseDate);
    });
    return unique;
  }

  // Movies only
  List<MediaItem> get movies {
    return allCredits.where((m) => m.mediaType == 'movie').toList();
  }

  // TV Shows only
  List<MediaItem> get tvShows {
    return allCredits.where((m) => m.mediaType == 'tv').toList();
  }
}

class ActorAwards {
  final int oscarWins;
  final int oscarNominations;
  final int baftaWins;
  final int baftaNominations;
  final int goldenGlobeWins;
  final int goldenGlobeNominations;
  final int totalWins;
  final int totalNominations;

  ActorAwards({
    required this.oscarWins,
    required this.oscarNominations,
    required this.baftaWins,
    required this.baftaNominations,
    required this.goldenGlobeWins,
    required this.goldenGlobeNominations,
    required this.totalWins,
    required this.totalNominations,
  });

  factory ActorAwards.empty() {
    return ActorAwards(
      oscarWins: 0,
      oscarNominations: 0,
      baftaWins: 0,
      baftaNominations: 0,
      goldenGlobeWins: 0,
      goldenGlobeNominations: 0,
      totalWins: 0,
      totalNominations: 0,
    );
  }

  factory ActorAwards.fromAggregatedJson(Map<String, dynamic> json) {
    return ActorAwards(
      oscarWins: json['oscarWins'] ?? 0,
      oscarNominations: json['oscarNominations'] ?? 0,
      baftaWins: json['baftaWins'] ?? 0,
      baftaNominations: json['baftaNominations'] ?? 0,
      goldenGlobeWins: json['goldenGlobeWins'] ?? 0,
      goldenGlobeNominations: json['goldenGlobeNominations'] ?? 0,
      totalWins: json['totalWins'] ?? 0,
      totalNominations: json['totalNominations'] ?? 0,
    );
  }
}
