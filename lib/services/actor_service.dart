import 'package:finishd/Model/actor_model.dart';
import 'package:finishd/services/ratings_service.dart';
import 'package:tmdb_api/tmdb_api.dart';

class ActorService {
  // Using the same keys as found in fetchtrending.dart for consistency
  final TMDB _tmdb = TMDB(
    ApiKeys(
      '829afd9e186fc15a71a6dfe50f3d00ad',
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI4MjlhZmQ5ZTE4NmZjMTVhNzFhNmRmZTUwZjNkMDBhZCIsIm5iZiI6IjY1Y2E5NjM5ZjQ0ZjI3MDE0OTJkNzU3ZCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.yqT5XJko1-qlM6PNwYjutel_TQrDQ9L4AKP8KegIUG0',
    ),
    logConfig: const ConfigLogger(showLogs: true, showErrorLogs: true),
  );

  final RatingsService _ratingsService = RatingsService();

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

      // Create model first to use helper methods
      final actor = ActorModel.fromJson(data);

      // Fetch awards for top 5 knownFor credits
      final awards = await _aggregateAwards(actor.knownFor.take(5).toList());

      // Re-create with aggregated awards (since model is immutable and we handle this in fromJson or a copyWith)
      // Actually, let's inject it into the data map before parsing to keep it clean
      data['awards_data'] = {
        'oscarWins': awards.oscarWins,
        'oscarNominations': awards.oscarNominations,
        'baftaWins': awards.baftaWins,
        'baftaNominations': awards.baftaNominations,
        'goldenGlobeWins': awards.goldenGlobeWins,
        'goldenGlobeNominations': awards.goldenGlobeNominations,
        'totalWins': awards.totalWins,
        'totalNominations': awards.totalNominations,
      };

      return ActorModel.fromJson(data);
    } catch (e) {
      print('❌ Error fetching actor details for ID $personId: $e');
      return null;
    }
  }

  /// Aggregates awards from a list of media items
  Future<ActorAwards> _aggregateAwards(List<dynamic> credits) async {
    int oscarW = 0, oscarN = 0;
    int baftaW = 0, baftaN = 0;
    int ggW = 0, ggN = 0;
    int totalW = 0, totalN = 0;

    for (var credit in credits) {
      if (credit.id == null) continue;

      final ratings = await _ratingsService.getRatings(credit.id);
      if (ratings.awards.isNotEmpty) {
        final parsed = _parseAwardString(ratings.awards);
        oscarW += parsed['oscarW'] ?? 0;
        oscarN += parsed['oscarN'] ?? 0;
        baftaW += parsed['baftaW'] ?? 0;
        baftaN += parsed['baftaN'] ?? 0;
        ggW += parsed['ggW'] ?? 0;
        ggN += parsed['ggN'] ?? 0;
        totalW += parsed['totalW'] ?? 0;
        totalN += parsed['totalN'] ?? 0;
      }
    }

    return ActorAwards(
      oscarWins: oscarW,
      oscarNominations: oscarN,
      baftaWins: baftaW,
      baftaNominations: baftaN,
      goldenGlobeWins: ggW,
      goldenGlobeNominations: ggN,
      totalWins: totalW,
      totalNominations: totalN,
    );
  }

  /// Parses OMDb award string: "Won 2 Oscars. Another 144 wins & 129 nominations."
  Map<String, int> _parseAwardString(String awards) {
    final Map<String, int> results = {};

    // Oscars
    results['oscarW'] = _extractCount(awards, r'Won (\d+) Oscar');
    results['oscarN'] = _extractCount(awards, r'Nominated for (\d+) Oscar');

    // BAFTAs
    results['baftaW'] = _extractCount(awards, r'Won (\d+) BAFTA');
    results['baftaN'] = _extractCount(awards, r'Nominated for (\d+) BAFTA');

    // Golden Globes
    results['ggW'] = _extractCount(awards, r'Won (\d+) Golden Globe');
    results['ggN'] = _extractCount(awards, r'Nominated for (\d+) Golden Globe');

    // Total Wins/Nominations
    // Examples: "144 wins", "129 nominations"
    results['totalW'] = _extractCount(awards, r'(\d+) win');
    results['totalN'] = _extractCount(awards, r'(\d+) nomination');

    return results;
  }

  int _extractCount(String text, String pattern) {
    final regex = RegExp(pattern, caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }
}
