import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:finishd/models/feed_video.dart';

class YouTubeService {
  static const String _apiKey = 'AIzaSyAnU2lsmVb7lRZx3823XsltJ_sxGqbCkI0';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3/search';

  final Random _random = Random();

  // 45+ curated search queries (full list you provided)
  final List<String> _queries = [
    // TRAILERS (General)
    "official movie trailer 2024",
    "official movie trailer 2025",
    "new movie trailers",
    "upcoming movies 2025 trailer",
    "official teaser trailer 2024",
    "blockbuster movie trailer",
    "new netflix trailers 2024",
    "new disney+ trailer",
    "HBO max movie trailers",
    "Amazon Prime movie trailer 2024",

    // TV SHOWS
    "new tv show trailers 2024",
    "new tv show trailers 2025",
    "Netflix series trailer",
    "Disney+ series trailer",
    "HBO series trailer",

    // BEHIND THE SCENES
    "movie behind the scenes",
    "movie bts 2024",
    "marvel behind the scenes",
    "dc behind the scenes",
    "netflix behind the scenes",

    // ACTOR INTERVIEWS
    "movie actor interview 2024",
    "movie cast interview 2024",
    "funny movie cast interview",
    "press junket interview new movie",
    "celebrity interview trending 2024",
    "movie red carpet interview",
    "trending actors interview 2024",

    // YOUTUBE SHORTS
    "movie trailer short",
    "movie review shorts",
    "actor interview shorts",
    "funny movie scene shorts",
    "trending movie clip shorts",
    "bts movie short",
    "movie highlights short",
    "netflix short video",
    "trending movies shorts",
    "movie explainer shorts",

    // SPECIFIC POPULAR CATEGORIES
    "marvel movie trailer",
    "dc movie trailer",
    "horror movie trailer 2024",
    "action movie trailer 2024",
    "romance movie trailer 2024",
    "sci-fi movie trailer 2024",
    "thriller trailer 2024",
    "bollywood movie trailer 2024",
    "korean drama trailer 2024",

    // DISCOVERY CONTENT
    "trending movies and tv shows 2025",
    "viral movie clips 2024",
    "top movies 2024 trailer",
    "must watch movies 2024",
    "greatest movies trailer mix",
  ];

  String? _nextPageToken;

  /// Fetch videos from YouTube
  /// If [query] is provided, it uses that specific query.
  /// Otherwise, it picks a random query from the predefined list.
  Future<List<FeedVideo>> fetchVideos({
    String? query,
    String language = 'en',
  }) async {
    if (_apiKey.isEmpty) {
      print('⚠️ Missing YouTube API Key.');
      return [];
    }

    // Use provided query or select a random one
    final String searchQuery =
        query ?? _queries[_random.nextInt(_queries.length)];

    // 🎯 50% chance to ignore nextPageToken → makes content fresher
    // Only use page token if we are NOT using a specific query (random discovery mode)
    final bool usePageToken =
        query == null && _nextPageToken != null && _random.nextBool();
    final String pageTokenParam = usePageToken
        ? '&pageToken=$_nextPageToken'
        : '';

    final url = Uri.parse(
      '$_baseUrl?part=snippet&q=$searchQuery&type=video&maxResults=10&key=$_apiKey&videoDuration=short&videoEmbeddable=true&relevanceLanguage=$language$pageTokenParam',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 🎯 Store next page token, but randomly reset sometimes
        if (_random.nextInt(100) < 70) {
          _nextPageToken = data["nextPageToken"];
        } else {
          _nextPageToken = null; // forces fresh results
        }

        final List<dynamic> items = data['items'];

        // Convert to FeedVideo
        final videos = items.map((item) => FeedVideo.fromJson(item)).toList();

        // 🎯 Shuffle videos to feel more random
        videos.shuffle(_random);

        return videos;
      } else {
        print("YouTube Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Exception fetching videos: $e");
      return [];
    }
  }
}
