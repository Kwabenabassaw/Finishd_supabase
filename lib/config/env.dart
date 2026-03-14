import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String _get(String key, [String fallback = '']) {
    try {
      final fromDotEnv = dotenv.env[key];
      if (fromDotEnv != null && fromDotEnv.isNotEmpty) {
        return fromDotEnv;
      }
    } catch (e) {
      // dotenv is either not initialized (missing .env file) or threw an error.
      // We safely fall through to the fallback arguments.
    }
    return fallback;
  }

  static String get supabaseUrl => _get('SUPABASE_URL', const String.fromEnvironment('SUPABASE_URL'));
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY', const String.fromEnvironment('SUPABASE_ANON_KEY'));
  static String get watchmodeApiKey => _get('WATCHMODE_API_KEY', const String.fromEnvironment('WATCHMODE_API_KEY'));
  static String get streamingAvailabilityApiKey =>
      _get('STREAMING_AVAILABILITY_API_KEY', const String.fromEnvironment('STREAMING_AVAILABILITY_API_KEY'));
  static String get youtubeApiKey => _get('YOUTUBE_API_KEY', const String.fromEnvironment('YOUTUBE_API_KEY'));
  static String get tmdbApiKey => _get('TMDB_API_KEY', const String.fromEnvironment('TMDB_API_KEY'));
  static String get tmdbReadAccessToken => _get('TMDB_READ_ACCESS_TOKEN', const String.fromEnvironment('TMDB_READ_ACCESS_TOKEN'));
  static String get omdbApiKey => _get('OMDB_API_KEY', const String.fromEnvironment('OMDB_API_KEY'));
  static String get klipyApiKey => _get('KLIPY_API_KEY', const String.fromEnvironment('KLIPY_API_KEY'));
  static String get vertexAiApiKey => _get('VERTEX_AI_API_KEY', const String.fromEnvironment('VERTEX_AI_API_KEY'));
  static String get simklApiKey => _get('SIMKL_API_KEY', const String.fromEnvironment('SIMKL_API_KEY'));
  static String get googleWebClientId => _get('GOOGLE_WEB_CLIENT_ID', const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'));
  static String get googleIosClientId => _get('GOOGLE_IOS_CLIENT_ID', const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'));
  static String get traktClientId => _get('TRAKT_CLIENT_ID', const String.fromEnvironment('TRAKT_CLIENT_ID'));
  static String get traktClientSecret => _get('TRAKT_CLIENT_SECRET', const String.fromEnvironment('TRAKT_CLIENT_SECRET'));
}
