import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/friend_activity.dart';
import '../Model/movie_list_item.dart';

class SocialDatabaseHelper {
  static final SocialDatabaseHelper _instance =
      SocialDatabaseHelper._internal();
  static Database? _database;

  factory SocialDatabaseHelper() => _instance;

  SocialDatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'social_cache.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Friend activity table
    await db.execute('''
      CREATE TABLE friend_activity(
        itemId TEXT,
        friendUid TEXT,
        friendName TEXT,
        avatarUrl TEXT,
        status TEXT,
        timestamp INTEGER,
        PRIMARY KEY (itemId, friendUid)
      )
    ''');
    await db.execute('CREATE INDEX idx_itemId ON friend_activity(itemId)');

    // User's own lists table
    await db.execute('''
      CREATE TABLE user_list_item(
        id TEXT,
        listType TEXT,
        title TEXT,
        posterPath TEXT,
        mediaType TEXT,
        genre TEXT,
        addedAt INTEGER,
        rating INTEGER,
        PRIMARY KEY (id, listType)
      )
    ''');
    await db.execute('CREATE INDEX idx_listType ON user_list_item(listType)');

    // Favorite posts table
    await db.execute('''
      CREATE TABLE favorite_posts(
        postId TEXT PRIMARY KEY,
        showId INTEGER NOT NULL,
        addedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS friend_activity');
    }
    if (oldVersion < 3) {
      // Add user_list_item table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_list_item(
          id TEXT,
          listType TEXT,
          title TEXT,
          posterPath TEXT,
          mediaType TEXT,
          genre TEXT,
          addedAt INTEGER,
          rating INTEGER,
          PRIMARY KEY (id, listType)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_listType ON user_list_item(listType)',
      );
    }
    // Recreate friend_activity if needed
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS friend_activity(
          itemId TEXT,
          friendUid TEXT,
          friendName TEXT,
          avatarUrl TEXT,
          status TEXT,
          timestamp INTEGER,
          PRIMARY KEY (itemId, friendUid)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_itemId ON friend_activity(itemId)',
      );
    }
    if (oldVersion < 4) {
      // Add favorite_posts table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS favorite_posts(
          postId TEXT PRIMARY KEY,
          showId INTEGER NOT NULL,
          addedAt INTEGER NOT NULL
        )
      ''');
    }
  }

  Future<void> insertActivity(FriendActivity activity) async {
    final db = await database;
    await db.insert(
      'friend_activity',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertActivities(List<FriendActivity> activities) async {
    final db = await database;
    final batch = db.batch();
    for (var activity in activities) {
      batch.insert(
        'friend_activity',
        activity.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<FriendActivity>> getActivitiesForItem(String itemId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'friend_activity',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return FriendActivity.fromMap(maps[i]);
    });
  }

  Future<void> clearOldActivities(int olderThanTimestamp) async {
    final db = await database;
    await db.delete(
      'friend_activity',
      where: 'timestamp < ?',
      whereArgs: [olderThanTimestamp],
    );
  }

  /// Clear all user-specific data from the social database.
  /// Call this on logout to prevent data leaking between accounts.
  Future<void> clearAllUserData() async {
    final db = await database;
    print('🧹 [SocialDatabaseHelper] Clearing all user data...');

    try {
      // Clear friend activity
      await db.delete('friend_activity');

      // Clear user's movie lists (FinishD, Watching, Watch Later)
      await db.delete('user_list_item');

      // Clear favorite posts
      await db.delete('favorite_posts');

      // Clear favorite communities (if table exists)
      try {
        await db.delete('favorite_communities');
      } catch (e) {
        // Table might not exist yet
      }

      print('✅ [SocialDatabaseHelper] Cleared all user data');
    } catch (e) {
      print('❌ [SocialDatabaseHelper] Error clearing user data: $e');
    }
  }

  /// Legacy method - kept for backwards compatibility
  Future<void> clearAll() async {
    await clearAllUserData();
  }

  // ==================== USER LIST METHODS ====================

  /// Insert or update a movie in the user's list
  Future<void> insertListItem(String listType, MovieListItem item) async {
    final db = await database;
    await db.insert('user_list_item', {
      'id': item.id,
      'listType': listType,
      'title': item.title,
      'posterPath': item.posterPath,
      'mediaType': item.mediaType,
      'genre': item.genre,
      'addedAt': item.addedAt.millisecondsSinceEpoch,
      'rating': item.rating,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove a movie from a specific list
  Future<void> removeListItem(String listType, String id) async {
    final db = await database;
    await db.delete(
      'user_list_item',
      where: 'id = ? AND listType = ?',
      whereArgs: [id, listType],
    );
  }

  /// Get all movies from a specific list
  Future<List<MovieListItem>> getListItems(String listType) async {
    final db = await database;
    final maps = await db.query(
      'user_list_item',
      where: 'listType = ?',
      whereArgs: [listType],
      orderBy: 'addedAt DESC',
    );

    return maps
        .map(
          (m) => MovieListItem(
            id: m['id'] as String,
            title: m['title'] as String,
            posterPath: m['posterPath'] as String?,
            mediaType: m['mediaType'] as String,
            genre: m['genre'] as String? ?? '',
            addedAt: DateTime.fromMillisecondsSinceEpoch(m['addedAt'] as int),
            rating: m['rating'] as int?,
          ),
        )
        .toList();
  }

  /// Sync entire list from Firestore (replace all items for that list type)
  Future<void> syncList(String listType, List<MovieListItem> items) async {
    final db = await database;
    final batch = db.batch();

    // Delete old items for this list
    batch.delete(
      'user_list_item',
      where: 'listType = ?',
      whereArgs: [listType],
    );

    // Insert new items
    for (var item in items) {
      batch.insert('user_list_item', {
        'id': item.id,
        'listType': listType,
        'title': item.title,
        'posterPath': item.posterPath,
        'mediaType': item.mediaType,
        'genre': item.genre,
        'addedAt': item.addedAt.millisecondsSinceEpoch,
        'rating': item.rating,
      });
    }

    await batch.commit(noResult: true);
  }

  /// Clear a specific list
  Future<void> clearList(String listType) async {
    final db = await database;
    await db.delete(
      'user_list_item',
      where: 'listType = ?',
      whereArgs: [listType],
    );
  }

  // ==================== FAVORITE POSTS METHODS ====================

  /// Add a post to favorites
  Future<void> addFavoritePost(String postId, int showId) async {
    final db = await database;
    await db.insert('favorite_posts', {
      'postId': postId,
      'showId': showId,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove a post from favorites
  Future<void> removeFavoritePost(String postId) async {
    final db = await database;
    await db.delete('favorite_posts', where: 'postId = ?', whereArgs: [postId]);
  }

  /// Check if a post is favorited
  Future<bool> isFavoritePost(String postId) async {
    final db = await database;
    final result = await db.query(
      'favorite_posts',
      where: 'postId = ?',
      whereArgs: [postId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get all favorite post IDs
  Future<Set<String>> getFavoritePostIds() async {
    final db = await database;
    final result = await db.query('favorite_posts');
    return result.map((row) => row['postId'] as String).toSet();
  }

  /// Get favorite post IDs for a specific show/community
  Future<Set<String>> getFavoritePostIdsForShow(int showId) async {
    final db = await database;
    final result = await db.query(
      'favorite_posts',
      where: 'showId = ?',
      whereArgs: [showId],
    );
    return result.map((row) => row['postId'] as String).toSet();
  }

  // ==================== FAVORITE COMMUNITIES METHODS ====================

  /// Add a community to favorites
  Future<void> addFavoriteCommunity(int showId, String showTitle) async {
    final db = await database;
    // Create table if not exists (for initial migration)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_communities(
        showId INTEGER PRIMARY KEY,
        showTitle TEXT NOT NULL,
        addedAt INTEGER NOT NULL
      )
    ''');
    await db.insert('favorite_communities', {
      'showId': showId,
      'showTitle': showTitle,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Remove a community from favorites
  Future<void> removeFavoriteCommunity(int showId) async {
    final db = await database;
    await db.delete(
      'favorite_communities',
      where: 'showId = ?',
      whereArgs: [showId],
    );
  }

  /// Check if a community is favorited
  Future<bool> isFavoriteCommunity(int showId) async {
    final db = await database;
    try {
      final result = await db.query(
        'favorite_communities',
        where: 'showId = ?',
        whereArgs: [showId],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      // Table might not exist yet
      return false;
    }
  }

  /// Get all favorite community IDs
  Future<Set<int>> getFavoriteCommunityIds() async {
    final db = await database;
    try {
      final result = await db.query('favorite_communities');
      return result.map((row) => row['showId'] as int).toSet();
    } catch (e) {
      // Table might not exist yet
      return {};
    }
  }
}
