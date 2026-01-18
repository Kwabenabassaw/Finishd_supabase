import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finishd_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8, // Upgraded to 8 for Movie Lists sync tracking
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Feed Cache
    await db.execute('''
      CREATE TABLE feed_cache (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 2. Trending Cache
    await db.execute('''
      CREATE TABLE trending_cache (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 3. Ratings Cache
    await db.execute('''
      CREATE TABLE ratings_cache (
        movieId TEXT PRIMARY KEY,
        imdbRating TEXT,
        metascore TEXT,
        tomatoRating TEXT,
        json TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 4. Notifications Cache (v2)
    await db.execute('''
      CREATE TABLE notifications_cache (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        json TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 5. TMDB Full Metadata Cache (v3)
    await db.execute('''
      CREATE TABLE tmdb_cache (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        json TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 6. Streaming Availability Cache (v4)
    await db.execute('''
      CREATE TABLE streaming_cache (
        id TEXT PRIMARY KEY,
        json TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 7. Recommendation Cache (v5)
    await db.execute('''
      CREATE TABLE recommendation_cache (
        cache_key TEXT PRIMARY KEY,
        friend_ids TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 8. Following Cache (v6) - 24h TTL
    await db.execute('''
      CREATE TABLE following_cache (
        user_id TEXT PRIMARY KEY,
        following_ids TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 9. Followers Cache (v6) - 24h TTL
    await db.execute('''
      CREATE TABLE followers_cache (
        user_id TEXT PRIMARY KEY,
        follower_ids TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 10. User Profile Cache (v6) - 7 day TTL
    await db.execute('''
      CREATE TABLE user_profile_cache (
        uid TEXT PRIMARY KEY,
        profile_data TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 11. Recommendations Received Cache (v7) - Hybrid approach
    await db.execute('''
      CREATE TABLE recommendations_received_cache (
        user_id TEXT NOT NULL,
        recommendation_id TEXT PRIMARY KEY,
        recommendation_data TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    // Track last sync time per user
    await db.execute('''
      CREATE TABLE recommendation_sync_status (
        user_id TEXT PRIMARY KEY,
        last_sync_timestamp INTEGER NOT NULL
      )
    ''');

    // 12. Movie List Sync Status (v8) - Track hybrid sync per list
    await db.execute('''
      CREATE TABLE movie_list_sync_status (
        user_id TEXT NOT NULL,
        list_type TEXT NOT NULL,
        last_sync_timestamp INTEGER NOT NULL,
        PRIMARY KEY (user_id, list_type)
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add notifications_cache table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications_cache (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          json TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add tmdb_cache table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tmdb_cache (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          json TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      // Add streaming_cache table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS streaming_cache (
          id TEXT PRIMARY KEY,
          json TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 5) {
      // Add recommendation_cache table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recommendation_cache (
          cache_key TEXT PRIMARY KEY,
          friend_ids TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      // Add social graph cache tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS following_cache (
          user_id TEXT PRIMARY KEY,
          following_ids TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS followers_cache (
          user_id TEXT PRIMARY KEY,
          follower_ids TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile_cache (
          uid TEXT PRIMARY KEY,
          profile_data TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      // Add recommendations cache tables (hybrid approach)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recommendations_received_cache (
          user_id TEXT NOT NULL,
          recommendation_id TEXT PRIMARY KEY,
          recommendation_data TEXT NOT NULL,
          timestamp INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS recommendation_sync_status (
          user_id TEXT PRIMARY KEY,
          last_sync_timestamp INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      // Add movie list sync tracking
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movie_list_sync_status (
          user_id TEXT NOT NULL,
          list_type TEXT NOT NULL,
          last_sync_timestamp INTEGER NOT NULL,
          PRIMARY KEY (user_id, list_type)
        )
      ''');
    }
  }

  /// Clear all user-specific data from the local database.
  /// Call this on logout to prevent data leaking between accounts.
  Future<void> clearAllUserData() async {
    final db = await database;

    print('🧹 [AppDatabase] Clearing all user data from local cache...');

    try {
      // Clear all user-related tables
      await db.delete('feed_cache');
      await db.delete('notifications_cache');
      await db.delete('recommendation_cache');
      await db.delete('following_cache');
      await db.delete('followers_cache');
      await db.delete('user_profile_cache');
      await db.delete('recommendations_received_cache');
      await db.delete('recommendation_sync_status');
      await db.delete('movie_list_sync_status');

      // Note: keeping trending_cache, ratings_cache, tmdb_cache, streaming_cache
      // as these are not user-specific (they store movie/show metadata)

      print('✅ [AppDatabase] Cleared all user data from local cache');
    } catch (e) {
      print('❌ [AppDatabase] Error clearing user data: $e');
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
