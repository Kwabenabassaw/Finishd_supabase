import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String _get(String key) {
    final fromDotEnv = dotenv.env[key];
    if (fromDotEnv != null && fromDotEnv.isNotEmpty) {
      return fromDotEnv;
    }

    final fromDefine = const String.fromEnvironment(key);
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }

    return '';
  }

  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');
  static String get watchmodeApiKey => _get('WATCHMODE_API_KEY');
  static String get streamingAvailabilityApiKey =>
      _get('STREAMING_AVAILABILITY_API_KEY');
  static String get youtubeApiKey => _get('YOUTUBE_API_KEY');
  static String get tmdbApiKey => _get('TMDB_API_KEY');
  static String get tmdbReadAccessToken => _get('TMDB_READ_ACCESS_TOKEN');
  static String get omdbApiKey => _get('OMDB_API_KEY');
  static String get klipyApiKey => _get('KLIPY_API_KEY');
  static String get vertexAiApiKey => _get('VERTEX_AI_API_KEY');
  static String get simklApiKey => _get('SIMKL_API_KEY');
  static String get googleWebClientId => _get('GOOGLE_WEB_CLIENT_ID');
  static String get googleIosClientId => _get('GOOGLE_IOS_CLIENT_ID');
  static String get traktClientId => _get('TRAKT_CLIENT_ID');
  static String get traktClientSecret => _get('TRAKT_CLIENT_SECRET');
}
