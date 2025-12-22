import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finishd/Model/streaming_availability.dart';
import 'package:finishd/services/cache/streaming_cache_service.dart';

class StreamingAvailabilityService {
  static const String _host = 'streaming-availability.p.rapidapi.com';
  // ⚠️ TODO: Move this to a secure config or environment variable
  static const String _apiKey =
      '4b246976bcmsha8abf2a7fce59c3p1d0fd5jsn4023c35ebc41';

  // Fallback logo URLs for known streaming services (using TMDB provider logos - reliable PNG format)
  static const Map<String, String> _fallbackLogos = {
    'netflix':
        'https://image.tmdb.org/t/p/original/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg',
    'prime':
        'https://image.tmdb.org/t/p/original/dQeAar5H991VYporEjUspolDarG.jpg',
    'disney':
        'https://image.tmdb.org/t/p/original/7rwgEs15tFwyR9NPQ5vpzxTj19Q.jpg',
    'max':
        'https://image.tmdb.org/t/p/original/6Q3ZYUNA9Hsgj6iWnVsw2gR5V6z.jpg',
    'hulu':
        'https://image.tmdb.org/t/p/original/zxrVdFjIjLqkfnwyghnfywTn3Lh.jpg',
    'apple':
        'https://image.tmdb.org/t/p/original/6uhKBfmtzFqOcLousHwZuzcrScK.jpg',
    'paramountplus':
        'https://image.tmdb.org/t/p/original/xbhHHa1YgtpwhC8lb1NQ3ACVcLd.jpg',
    'peacock':
        'https://image.tmdb.org/t/p/original/8VCV78prwd9QzZnEm0ReO6bERDa.jpg',
    'starz':
        'https://image.tmdb.org/t/p/original/eWp5LdR4p4uKL0wACBBXapDV2lB.jpg',
    'showtime':
        'https://image.tmdb.org/t/p/original/Ajqyt5aNxNGjmF9uOfxArGrdf3X.jpg',
    'crunchyroll':
        'https://image.tmdb.org/t/p/original/hNO3eCEnewPxzGLsFJT2sL0D2N4.jpg',
    'fubo':
        'https://image.tmdb.org/t/p/original/iklTy1RwaJGEYGz73nKs6HGTIFQ.jpg',
    'amc':
        'https://image.tmdb.org/t/p/original/xlonQMSmhtA2HHwK3JKF9ghx7Po.jpg',
    'britbox':
        'https://image.tmdb.org/t/p/original/aGIS8maihUm60A3moKYD9gfYHYT.jpg',
    'mubi':
        'https://image.tmdb.org/t/p/original/rVKCtTkuCjgek0qY8pwEyoxHUxu.jpg',
    'curiosity':
        'https://image.tmdb.org/t/p/original/67Ee4E6qOkQGHeUTArdJ1qRxzR2.jpg',
    'tubi':
        'https://image.tmdb.org/t/p/original/w0qJQm1HiXlylUNBqkM0GNGaVoo.jpg',
    'pluto':
        'https://image.tmdb.org/t/p/original/t6N57S17sdXRXmZDAkaGP0NHNG0.jpg',
  };

  // Fallback display names for services
  static const Map<String, String> _fallbackNames = {
    'netflix': 'Netflix',
    'prime': 'Prime Video',
    'disney': 'Disney+',
    'max': 'Max',
    'hulu': 'Hulu',
    'apple': 'Apple TV+',
    'paramountplus': 'Paramount+',
    'peacock': 'Peacock',
    'starz': 'STARZ',
    'showtime': 'Showtime',
    'crunchyroll': 'Crunchyroll',
    'fubo': 'Fubo',
    'amc': 'AMC+',
    'britbox': 'BritBox',
    'mubi': 'MUBI',
    'curiosity': 'CuriosityStream',
    'tubi': 'Tubi',
    'pluto': 'Pluto TV',
  };

  // No longer using Firestore for streaming availability to avoid permission issues

  /// Fetches streaming availability for a movie or TV show using its TMDB ID
  /// Filters to USA only for efficiency
  Future<StreamingAvailability?> fetchAvailability(
    String tmdbId,
    String mediaType,
  ) async {
    // Correct format for RapidAPI v4: {type}/{tmdbId} e.g. "tv/200875"
    final String showId = "$mediaType/$tmdbId";
    final url = Uri.https(
      _host,
      '/shows/$showId',
      {'country': 'us'}, // Filter to USA only
    );

    try {
      print('🌐 Fetching streaming info for $showId from: $url');
      final response = await http.get(
        url,
        headers: {'X-RapidAPI-Key': _apiKey, 'X-RapidAPI-Host': _host},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Some versions/plans return the show object top-level, others nest it in 'result'
        final streamingInfo =
            data['streamingOptions'] ?? data['result']?['streamingOptions'];

        if (streamingInfo == null) {
          print(
            '⚠️ No streamingOptions found. Response snippet: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
          );
          return null;
        }

        return _simplifyResponse(streamingInfo);
      } else {
        print('❌ API Error (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      print('🚨 StreamingAvailabilityService Exception: $e');
      return null;
    }
  }

  /// Simplifies the RapidAPI response into our internal StreamingAvailability model
  StreamingAvailability _simplifyResponse(Map<String, dynamic> streamingInfo) {
    final Map<String, dynamic> simplified = {};

    // Map of RapidAPI service names to our normalized keys
    final serviceMap = {
      'netflix': 'netflix',
      'prime': 'prime',
      'amazon': 'prime',
      'disney': 'disney',
      'disneyplus': 'disney',
      'hbo': 'max',
      'max': 'max',
      'hbomax': 'max',
      'hulu': 'hulu',
      'apple': 'apple',
      'appletv': 'apple',
      'paramount': 'paramountplus',
      'paramountplus': 'paramountplus',
      'peacock': 'peacock',
      'peacocktv': 'peacock',
      'starz': 'starz',
      'showtime': 'showtime',
      'crunchyroll': 'crunchyroll',
      'fubo': 'fubo',
      'fubotv': 'fubo',
      'amc': 'amc',
      'amcplus': 'amc',
      'britbox': 'britbox',
      'mubi': 'mubi',
      'curiosity': 'curiosity',
      'curiositystream': 'curiosity',
      'tubi': 'tubi',
      'pluto': 'pluto',
      'plutotv': 'pluto',
    };

    print(
      '🔍 Parsing streamingOptions for ${streamingInfo.keys.length} countries...',
    );
    streamingInfo.forEach((countryCode, serviceList) {
      final countryKey = countryCode.toUpperCase();
      final Map<String, dynamic> countryServices = {};

      for (var s in serviceList) {
        // Safe access for 'service' - sometimes it's a Map, sometimes a String (service ID)
        dynamic serviceSource = s['service'];
        String? serviceId;
        String? displayName;
        String? logoUrl;

        if (serviceSource is String) {
          serviceId = serviceSource;
        } else if (serviceSource is Map) {
          serviceId = serviceSource['id']?.toString();
          displayName = serviceSource['name']?.toString();
          logoUrl =
              serviceSource['imageSet']?['lightThemeImage'] ??
              serviceSource['imageSet']?['whiteImage'] ??
              serviceSource['imageSet']?['darkThemeImage'];
        }

        if (serviceId == null) continue;

        // Strip prefixes if present (e.g. "netflix" vs "netflix.addon")
        final normalizedServiceId = serviceId.split('.').first.toLowerCase();
        final mappedKey = serviceMap[normalizedServiceId];

        if (mappedKey != null) {
          // Use fallback logo if API didn't provide one
          final finalLogoUrl = logoUrl ?? _fallbackLogos[mappedKey];
          // Use fallback name if API didn't provide one
          final finalName =
              displayName ??
              _fallbackNames[mappedKey] ??
              mappedKey.toUpperCase();

          countryServices[mappedKey] = {
            'link': s['link'] ?? "",
            'videoLink': s['videoLink'],
            'name': finalName,
            'logoUrl': finalLogoUrl,
          };
          print(
            '✅ Added $mappedKey for $countryKey (logo: ${finalLogoUrl != null ? "✓" : "✗"})',
          );
        } else {
          print('ℹ️ Skipped unknown service: $serviceId in $countryKey');
        }
      }

      if (countryServices.isNotEmpty) {
        simplified[countryKey] = countryServices;
      }
    });

    print(
      '📊 Simplified availability for ${simplified.keys.length} countries.',
    );

    return StreamingAvailability.fromJson(simplified);
  }

  /// Gets availability from local SQLite cache if it exists and is not stale
  Future<StreamingAvailability?> getAvailabilityFromCache(String tmdbId) async {
    try {
      final cachedMap = await StreamingCacheService.getStreamingAvailability(
        tmdbId,
      );
      if (cachedMap != null) {
        return StreamingAvailability.fromJson(cachedMap);
      }
    } catch (e) {
      print('Error getting availability from SQLite: $e');
    }
    return null;
  }

  /// Enriches a movie or TV show in local cache with streaming availability
  /// Implements the 24-hour freshness check.
  Future<void> enrichAvailabilityInCache({
    required String tmdbId,
    required String mediaType,
  }) async {
    try {
      // 1. Check if we already have fresh data in SQLite
      final existing = await StreamingCacheService.getStreamingAvailability(
        tmdbId,
      );
      if (existing != null) {
        return; // Fresh enough (getStreamingAvailability handles TTL)
      }

      print('✨ Fetching fresh streaming availability for TMDB: $tmdbId...');
      final availability = await fetchAvailability(tmdbId, mediaType);

      if (availability != null) {
        await StreamingCacheService.saveStreamingAvailability(
          tmdbId,
          availability.toJson(),
        );
        print('✅ Successfully cached $tmdbId in SQLite');
      }
    } catch (e) {
      print('Error enriching availability in SQLite: $e');
    }
  }
}
