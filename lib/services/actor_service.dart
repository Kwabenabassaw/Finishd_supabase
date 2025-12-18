import 'package:finishd/Model/actor_model.dart';
import 'package:tmdb_api/tmdb_api.dart'; // Direct TMDB Usage as per existing patterns

class ActorService {
  // Using the same keys as found in fetchtrending.dart for consistency
  final TMDB _tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
    logConfig: const ConfigLogger(showLogs: true, showErrorLogs: true),
  );

  /// Fetch full actor details including credits, images, and external IDs
  Future<ActorModel?> fetchActorDetails(int personId) async {
    try {
      final Map result = await _tmdb.v3.people.getDetails(
        personId,
        appendToResponse: 'combined_credits,external_ids,images',
        language: 'en-US',
      );

      // cast to Map<String, dynamic>
      final data = Map<String, dynamic>.from(result);

      return ActorModel.fromJson(data);
    } catch (e) {
      print('❌ Error fetching actor details for ID $personId: $e');
      return null;
    }
  }
}
