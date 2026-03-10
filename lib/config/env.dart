import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get watchmodeApiKey => dotenv.env['WATCHMODE_API_KEY'] ?? '';
  static String get streamingAvailabilityApiKey =>
      dotenv.env['STREAMING_AVAILABILITY_API_KEY'] ?? '';
  static String get youtubeApiKey => dotenv.env['YOUTUBE_API_KEY'] ?? '';
  static String get tmdbApiKey => dotenv.env['TMDB_API_KEY'] ?? '';
  static String get tmdbReadAccessToken =>
      dotenv.env['TMDB_READ_ACCESS_TOKEN'] ?? '';
  static String get omdbApiKey => dotenv.env['OMDB_API_KEY'] ?? '';
  static String get klipyApiKey => dotenv.env['KLIPY_API_KEY'] ?? '';
  static String get vertexAiApiKey => dotenv.env['VERTEX_AI_API_KEY'] ?? '';
  static String get simklApiKey => dotenv.env['SIMKL_API_KEY'] ?? '';
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  static String get googleIosClientId =>
      dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '';
  static String get traktClientId => dotenv.env['TRAKT_CLIENT_ID'] ?? '';
  static String get traktClientSecret =>
      dotenv.env['TRAKT_CLIENT_SECRET'] ?? '';
}
