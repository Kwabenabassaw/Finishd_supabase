import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/friend_activity.dart';

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
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
    await db.execute('''
      CREATE INDEX idx_itemId ON friend_activity(itemId)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Recreate table for new unique constraints
      await db.execute('DROP TABLE IF EXISTS friend_activity');
      await _onCreate(db, newVersion);
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

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('friend_activity');
  }
}
