import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for movies stored in user's lists (watching, watchlist, finished, favorites)
class MovieListItem {
  final String id;
  final String title;
  final String? posterPath;
  final String mediaType; // 'movie' or 'tv'
  final DateTime addedAt;

  MovieListItem({
    required this.id,
    required this.title,
    this.posterPath,
    required this.mediaType,
    required this.addedAt,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'mediaType': mediaType,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  // Create from Firestore document
  factory MovieListItem.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MovieListItem(
      id: data['id'] as String,
      title: data['title'] as String,
      posterPath: data['posterPath'] as String?,
      mediaType: data['mediaType'] as String,
      addedAt: (data['addedAt'] as Timestamp).toDate(),
    );
  }

  // Create from Firestore map (for subcollection queries)
  factory MovieListItem.fromMap(Map<String, dynamic> data) {
    return MovieListItem(
      id: data['id'] as String,
      title: data['title'] as String,
      posterPath: data['posterPath'] as String?,
      mediaType: data['mediaType'] as String,
      addedAt: (data['addedAt'] as Timestamp).toDate(),
    );
  }

  // Copy with method for updates
  MovieListItem copyWith({
    String? id,
    String? title,
    String? posterPath,
    String? mediaType,
    DateTime? addedAt,
  }) {
    return MovieListItem(
      id: id ?? this.id,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      mediaType: mediaType ?? this.mediaType,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
