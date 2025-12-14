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
      version: 3, // Upgraded from 2 to 3 for TMDB cache
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
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
