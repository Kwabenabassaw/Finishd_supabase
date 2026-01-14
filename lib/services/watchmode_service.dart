import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:finishd/services/cache/streaming_cache_service.dart';

/// Represents a streaming provider from Watchmode API
class StreamingProvider {
  final int sourceId;
  final String name;
  final String type; // sub, rent, buy, free
  final String region;
  final String webLink;
  final String logoUrl;
  final double? price;

  StreamingProvider({
    required this.sourceId,
    required this.name,
    required this.type,
    required this.region,
    required this.webLink,
    required this.logoUrl,
    this.price,
  });

  factory StreamingProvider.fromJson(Map<String, dynamic> json) {
    return StreamingProvider(
      sourceId: json['source_id'] ?? 0,
      name: json['name'] ?? json['source_name'] ?? 'Unknown',
      type: json['type'] ?? 'unknown',
      region: json['region'] ?? 'US',
      webLink: json['web_url'] ?? '',
      logoUrl: json['logo_100px'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source_id': sourceId,
      'name': name,
      'type': type,
      'region': region,
      'web_url': webLink,
      'logo_100px': logoUrl,
      'price': price,
    };
  }
}

/// Service to interact with Watchmode API for streaming availability
class WatchmodeService {
  static const String _baseUrl = 'https://api.watchmode.com/v1';
  // ⚠️ TODO: Move this to a secure config or environment variable
  static const String _apiKey =
      'pCVeStIEFu2Uki6NuXvKKuJFBFz8z4IpwINxga83'; // Replace with actual key

  /// Priority order for streaming types (subscription first, then free, then rent/buy)
  static const List<String> _typePriority = ['sub', 'free', 'rent', 'buy'];

  /// Cache for dynamically fetched source logos from /sources endpoint
  static Map<int, String>? _dynamicSourceLogos;
  static bool _isFetchingLogos = false;

  /// Expanded fallback logo URLs for known Watchmode source IDs (using TMDB provider logos)
  static const Map<int, String> _sourceLogos = {
    // Major streaming subscription services
    203:
        'https://image.tmdb.org/t/p/original/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg', // Netflix
    26: 'https://image.tmdb.org/t/p/original/dQeAar5H991VYporEjUspolDarG.jpg', // Prime Video
    372:
        'https://image.tmdb.org/t/p/original/7rwgEs15tFwyR9NPQ5vpzxTj19Q.jpg', // Disney+
    387:
        'https://image.tmdb.org/t/p/original/6Q3ZYUNA9Hsgj6iWnVsw2gR5V6z.jpg', // Max (HBO Max)
    157:
        'https://image.tmdb.org/t/p/original/zxrVdFjIjLqkfnwyghnfywTn3Lh.jpg', // Hulu
    371:
        'https://image.tmdb.org/t/p/original/6uhKBfmtzFqOcLousHwZuzcrScK.jpg', // Apple TV+
    444:
        'https://image.tmdb.org/t/p/original/xbhHHa1YgtpwhC8lb1NQ3ACVcLd.jpg', // Paramount+
    389:
        'https://image.tmdb.org/t/p/original/8VCV78prwd9QzZnEm0ReO6bERDa.jpg', // Peacock
    232:
        'https://image.tmdb.org/t/p/original/eWp5LdR4p4uKL0wACBBXapDV2lB.jpg', // Starz
    318:
        'https://image.tmdb.org/t/p/original/Ajqyt5aNxNGjmF9uOfxArGrdf3X.jpg', // Showtime
    // Free streaming services
    241:
        'https://image.tmdb.org/t/p/original/w0qJQm1HiXlylUNBqkM0GNGaVoo.jpg', // Tubi
    300:
        'https://image.tmdb.org/t/p/original/t6N57S17sdXRXmZDAkaGP0NHNG0.jpg', // Pluto TV
    442:
        'https://image.tmdb.org/t/p/original/1WEpKpLhT8ehdyJHn4R9hYoUXgz.jpg', // Plex
    457:
        'https://image.tmdb.org/t/p/original/fWqVPYArdFwBc6vYqoyQB6XUl85.jpg', // The Roku Channel
    398:
        'https://image.tmdb.org/t/p/original/xL9SUR63qrEjFZAhtsipskeAMR7.jpg', // Crackle
    123:
        'https://image.tmdb.org/t/p/original/ifhbNuuVnlwYy5oXA5VIb2YR8AZ.jpg', // Vudu Free
    459:
        'https://image.tmdb.org/t/p/original/zPGbhPAMVLOGhrANEFEzwOqRlKM.jpg', // Freevee (IMDb TV)
    // Live TV / Cable streaming
    373:
        'https://image.tmdb.org/t/p/original/iklTy1RwaJGEYGz73nKs6HGTIFQ.jpg', // fuboTV
    215:
        'https://image.tmdb.org/t/p/original/gJ3yVMWouaVj6iHd59TISJ1TlM5.jpg', // CBS
    376:
        'https://image.tmdb.org/t/p/original/bxdNcDbk1ohVeOMmM3eusAAiTLw.jpg', // Spectrum
    395:
        'https://image.tmdb.org/t/p/original/m6LhykG1WxLgPq4K3p3bLj5wG4Y.jpg', // DIRECTV
    // Rent/Buy services
    307:
        'https://image.tmdb.org/t/p/original/peURlLlr8jggOwK53fJ5wdQl05y.jpg', // Vudu
    349:
        'https://image.tmdb.org/t/p/original/tbEdFQDwx5LEVr8WpSeXQSIirVq.jpg', // Apple iTunes
    352:
        'https://image.tmdb.org/t/p/original/5NyLm42TmCqCMOZFvH4fcoSNKEW.jpg', // Google Play
    24: 'https://image.tmdb.org/t/p/original/seGSXajazLMCKGB5ber90VuGPpT.jpg', // Amazon Video
    192:
        'https://image.tmdb.org/t/p/original/pZ9TSk3wlRYwiwwRxTsQJ7t2but.jpg', // YouTube
    350:
        'https://image.tmdb.org/t/p/original/1W87E41jmwpnYswfTL4c4gYKJfP.jpg', // Redbox
    68: 'https://image.tmdb.org/t/p/original/paq2o2dIfQnxcERsVoq7Ys8KYz8.jpg', // Microsoft Store
    // Specialty/Niche streaming
    392:
        'https://image.tmdb.org/t/p/original/hNO3eCEnewPxzGLsFJT2sL0D2N4.jpg', // Crunchyroll
    386:
        'https://image.tmdb.org/t/p/original/xlonQMSmhtA2HHwK3JKF9ghx7Po.jpg', // AMC+
    425:
        'https://image.tmdb.org/t/p/original/aGIS8maihUm60A3moKYD9gfYHYT.jpg', // BritBox
    437:
        'https://image.tmdb.org/t/p/original/67Ee4E6qOkQGHeUTArdJ1qRxzR2.jpg', // CuriosityStream
    378:
        'https://image.tmdb.org/t/p/original/rVKCtTkuCjgek0qY8pwEyoxHUxu.jpg', // MUBI
    430:
        'https://image.tmdb.org/t/p/original/bmU37kpSMcXD5mLTqd8poJSreWj.jpg', // Shudder
    385:
        'https://image.tmdb.org/t/p/original/hR9vWd8hWEVQKD6eOnBneKRFEW3.jpg', // Discovery+
    455:
        'https://image.tmdb.org/t/p/original/9ghgSC0MA082EL6HLCW3GalykFD.jpg', // MGM+
    363:
        'https://image.tmdb.org/t/p/original/maJGYuJJEq9WtZqSFl4W6OAe8gn.jpg', // Kanopy
    432:
        'https://image.tmdb.org/t/p/original/krjE7bNiL2UsqBiQzMQPNy23Mg5.jpg', // Criterion Channel
    377:
        'https://image.tmdb.org/t/p/original/3E0RkIEQrrGYazs63NMsn3XONT6.jpg', // Sundance Now
    397:
        'https://image.tmdb.org/t/p/original/qBDBQlxRcJwqxp9IURQ0Z6sXxAF.jpg', // Acorn TV
    450:
        'https://image.tmdb.org/t/p/original/yT8wLFH72klyAs1v9xOmjNLe60N.jpg', // Hallmark Movies
    445:
        'https://image.tmdb.org/t/p/original/2joD3S2goOB6lmepX35A8dmaqgM.jpg', // HIDIVE (Anime)
    526:
        'https://image.tmdb.org/t/p/original/j5EiyYEqP2dKOdSYOByfKmYtNmF.jpg', // Fandango at Home
  };

  /// Fetch all source logos from the /sources endpoint once and cache them
  static Future<void> _fetchSourceLogos() async {
    if (_dynamicSourceLogos != null || _isFetchingLogos) return;
    _isFetchingLogos = true;

    try {
      final url = Uri.parse('$_baseUrl/sources/?apiKey=$_apiKey&regions=US');
      print('📥 Fetching all Watchmode sources for logo cache...');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _dynamicSourceLogos = {};

        for (var source in data) {
          final id = source['id'] as int? ?? 0;
          final logo = source['logo_100px']?.toString() ?? '';
          if (id > 0 && logo.isNotEmpty) {
            _dynamicSourceLogos![id] = logo;
          }
        }
        print('✅ Cached ${_dynamicSourceLogos!.length} source logos from API');
      } else {
        print('❌ Failed to fetch sources: ${response.statusCode}');
        _dynamicSourceLogos = {}; // Set empty to prevent retries
      }
    } catch (e) {
      print('🚨 Error fetching source logos: $e');
      _dynamicSourceLogos = {}; // Set empty to prevent retries
    } finally {
      _isFetchingLogos = false;
    }
  }

  /// Get logo URL for a source, checking dynamic cache, API response, then fallback
  static Future<String> _getLogoUrlAsync(
    int sourceId,
    String? apiLogoUrl,
  ) async {
    // 1. Use API-provided logo if available and non-empty
    if (apiLogoUrl != null && apiLogoUrl.isNotEmpty) {
      return apiLogoUrl;
    }

    // 2. Check dynamically fetched logos cache
    if (_dynamicSourceLogos != null &&
        _dynamicSourceLogos!.containsKey(sourceId)) {
      return _dynamicSourceLogos![sourceId]!;
    }

    // 3. Fall back to hardcoded logos
    return _sourceLogos[sourceId] ?? '';
  }

  /// Synchronous version for backward compatibility (uses cache only)
  static String _getLogoUrl(int sourceId, String? apiLogoUrl) {
    // Use API-provided logo if available
    if (apiLogoUrl != null && apiLogoUrl.isNotEmpty) {
      return apiLogoUrl;
    }
    // Check dynamically fetched logos
    if (_dynamicSourceLogos != null &&
        _dynamicSourceLogos!.containsKey(sourceId)) {
      return _dynamicSourceLogos![sourceId]!;
    }
    // Fall back to our hardcoded logos
    return _sourceLogos[sourceId] ?? '';
  }

  /// Get Watchmode ID from TMDB ID
  Future<Map<String, dynamic>?> _getWatchmodeId(
    String tmdbId,
    String mediaType,
  ) async {
    // Watchmode uses 'tmdb_movie_id' or 'tmdb_tv_id' as search field
    final searchField = mediaType == 'movie' ? 'tmdb_movie_id' : 'tmdb_tv_id';
    final url = Uri.parse(
      '$_baseUrl/search/?apiKey=$_apiKey&search_field=$searchField&search_value=$tmdbId',
    );

    try {
      print(
        '🔍 Watchmode: Converting TMDB $tmdbId ($mediaType) to Watchmode ID...',
      );
      print('🔗 URL: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📦 Response data: $data');

        if (data['title_results'] != null && data['title_results'].isNotEmpty) {
          final result = data['title_results'][0];
          print('✅ Watchmode ID: ${result['id']}');
          return {'id': result['id'], 'type': result['type']};
        } else {
          print('⚠️ No title_results in response for TMDB $tmdbId');
        }
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      print('🚨 Watchmode search error: $e');
      return null;
    }
  }

  /// Fetch streaming sources from Watchmode
  Future<List<StreamingProvider>> _fetchSources(int watchmodeId) async {
    final url = Uri.parse(
      '$_baseUrl/title/$watchmodeId/sources/?apiKey=$_apiKey&regions=US',
    );

    try {
      print('🌐 Fetching streaming sources for Watchmode ID: $watchmodeId...');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final providers = <StreamingProvider>[];
        final seenSources = <int>{};

        for (var source in data) {
          final sourceId = source['source_id'] as int? ?? 0;

          // Skip duplicates (same source can appear multiple times for different qualities)
          if (seenSources.contains(sourceId)) continue;
          seenSources.add(sourceId);

          // Only include sources with valid web URLs
          if (source['web_url'] != null &&
              source['web_url'].toString().isNotEmpty) {
            // Get logo URL with fallback
            final apiLogoUrl = source['logo_100px']?.toString();
            final logoUrl = _getLogoUrl(sourceId, apiLogoUrl);

            final provider = StreamingProvider(
              sourceId: sourceId,
              name: source['name'] ?? source['source_name'] ?? 'Unknown',
              type: source['type'] ?? 'unknown',
              region: source['region'] ?? 'US',
              webLink: source['web_url'] ?? '',
              logoUrl: logoUrl,
              price: source['price'] != null
                  ? (source['price'] as num).toDouble()
                  : null,
            );

            providers.add(provider);
            print(
              '📺 Added: ${provider.name} (ID: $sourceId, logo: ${logoUrl.isNotEmpty ? "✓" : "✗"})',
            );
          }
        }

        // Sort by type priority (sub first, then free, then rent/buy)
        providers.sort((a, b) {
          final aIndex = _typePriority.indexOf(a.type);
          final bIndex = _typePriority.indexOf(b.type);
          return (aIndex == -1 ? 99 : aIndex).compareTo(
            bIndex == -1 ? 99 : bIndex,
          );
        });

        print('✅ Found ${providers.length} unique streaming providers');
        return providers;
      } else {
        print('❌ Watchmode sources error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('🚨 Watchmode sources exception: $e');
      return [];
    }
  }

  /// Get streaming providers for a movie/TV show
  /// Uses caching to minimize API calls
  Future<List<StreamingProvider>> getStreamingProviders(
    String tmdbId,
    String mediaType,
  ) async {
    // 0. Pre-fetch source logos if not already cached
    await _fetchSourceLogos();

    // 1. Check cache first
    final cached = await _getCachedProviders(tmdbId);
    if (cached != null) {
      print('📦 Using cached providers for TMDB $tmdbId');
      return cached;
    }

    // 2. Get Watchmode ID from TMDB ID
    final watchmodeData = await _getWatchmodeId(tmdbId, mediaType);
    if (watchmodeData == null) {
      return [];
    }

    // 3. Fetch streaming sources
    final watchmodeId = watchmodeData['id'] as int;
    final providers = await _fetchSources(watchmodeId);

    // 4. Cache the results
    if (providers.isNotEmpty) {
      await _cacheProviders(tmdbId, providers);
    }

    return providers;
  }

  /// Get cached providers from SQLite
  Future<List<StreamingProvider>?> _getCachedProviders(String tmdbId) async {
    try {
      final cachedData = await StreamingCacheService.getStreamingAvailability(
        'watchmode_$tmdbId',
      );
      if (cachedData != null && cachedData['providers'] is List) {
        final List<dynamic> providerList = cachedData['providers'];
        return providerList
            .map((p) => StreamingProvider.fromJson(p as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error reading Watchmode cache: $e');
    }
    return null;
  }

  /// Cache providers to SQLite
  Future<void> _cacheProviders(
    String tmdbId,
    List<StreamingProvider> providers,
  ) async {
    try {
      await StreamingCacheService.saveStreamingAvailability(
        'watchmode_$tmdbId',
        {'providers': providers.map((p) => p.toJson()).toList()},
      );
      print('💾 Cached ${providers.length} providers for TMDB $tmdbId');
    } catch (e) {
      print('Error caching Watchmode data: $e');
    }
  }

  /// Clear cache for a specific item
  Future<void> clearCache(String tmdbId) async {
    await StreamingCacheService.clear('watchmode_$tmdbId');
  }

  /// Clear all Watchmode cache
  Future<void> clearAllCache() async {
    await StreamingCacheService.clearAll();
  }
}
