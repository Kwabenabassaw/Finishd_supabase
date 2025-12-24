import 'package:cloud_firestore/cloud_firestore.dart';

/// Model class for movie ratings from multiple sources
/// Supports IMDb, Rotten Tomatoes, and Metacritic ratings
class MovieRatings {
  final String imdbId;
  final String imdbRating;
  final String rotten;
  final String metacritic;
  final String imdbVotes;
  final String awards;
  final DateTime lastUpdated;

  MovieRatings({
    required this.imdbId,
    required this.imdbRating,
    required this.rotten,
    required this.metacritic,
    required this.imdbVotes,
    required this.awards,
    required this.lastUpdated,
  });

  /// Creates a MovieRatings instance from Firestore document
  factory MovieRatings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MovieRatings(
      imdbId: data['imdbId'] ?? '',
      imdbRating: data['imdbRating'] ?? 'N/A',
      rotten: data['rotten'] ?? 'N/A',
      metacritic: data['metacritic'] ?? 'N/A',
      imdbVotes: data['imdbVotes'] ?? '0',
      awards: data['awards'] ?? '',
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Creates a MovieRatings instance from OMDb API response
  factory MovieRatings.fromOmdbJson(Map<String, dynamic> json, String imdbId) {
    // Extract ratings from the Ratings array
    String rottenTomatoes = 'N/A';
    String metacritic = 'N/A';

    if (json['Ratings'] != null && json['Ratings'] is List) {
      for (var rating in json['Ratings']) {
        if (rating['Source'] == 'Rotten Tomatoes') {
          rottenTomatoes = rating['Value'] ?? 'N/A';
        } else if (rating['Source'] == 'Metacritic') {
          metacritic = rating['Value'] ?? 'N/A';
        }
      }
    }

    return MovieRatings(
      imdbId: imdbId,
      imdbRating: json['imdbRating'] ?? 'N/A',
      rotten: rottenTomatoes,
      metacritic: metacritic,
      imdbVotes: json['imdbVotes'] ?? '0',
      awards: json['Awards'] ?? '',
      lastUpdated: DateTime.now(),
    );
  }

  /// Creates an empty MovieRatings instance as fallback
  factory MovieRatings.empty() {
    return MovieRatings(
      imdbId: '',
      imdbRating: 'N/A',
      rotten: 'N/A',
      metacritic: 'N/A',
      imdbVotes: '0',
      awards: '',
      lastUpdated: DateTime.now(),
    );
  }

  /// Converts MovieRatings to Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'imdbId': imdbId,
      'imdbRating': imdbRating,
      'rotten': rotten,
      'metacritic': metacritic,
      'imdbVotes': imdbVotes,
      'awards': awards,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Checks if the cached data is still fresh (within 7 days)
  bool isFresh() {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inDays < 7;
  }

  /// Checks if ratings data is available
  bool get hasData {
    return imdbId.isNotEmpty &&
        (imdbRating != 'N/A' || rotten != 'N/A' || metacritic != 'N/A');
  }

  @override
  String toString() {
    return 'MovieRatings(imdbId: $imdbId, imdbRating: $imdbRating, '
        'rotten: $rotten, metacritic: $metacritic, imdbVotes: $imdbVotes)';
  }
}
