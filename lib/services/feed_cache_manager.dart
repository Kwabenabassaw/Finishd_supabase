import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finishd/models/feed_item.dart';

/// Local cache manager for feed data
/// Enables instant feed display on app open/return
class FeedCacheManager {
  static const String _feedCacheKey = 'cached_feed_items';
  static const String _feedTimestampKey = 'cached_feed_timestamp';
  static const int _cacheMaxAgeMinutes = 30; // Cache valid for 30 mins
  
  static FeedCacheManager? _instance;
  SharedPreferences? _prefs;
  
  FeedCacheManager._();
  
  static FeedCacheManager get instance {
    _instance ??= FeedCacheManager._();
    return _instance!;
  }
  
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  /// Save feed items to local cache
  Future<void> cacheFeed(List<FeedItem> items) async {
    await _ensureInitialized();
    
    try {
      final jsonList = items.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await _prefs!.setString(_feedCacheKey, jsonString);
      await _prefs!.setInt(_feedTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      print('📦 Cached ${items.length} feed items locally');
    } catch (e) {
      print('❌ Error caching feed: $e');
    }
  }
  
  /// Get cached feed items (returns empty if expired or not found)
  Future<List<FeedItem>> getCachedFeed({bool ignoreExpiry = false}) async {
    await _ensureInitialized();
    
    try {
      final jsonString = _prefs!.getString(_feedCacheKey);
      if (jsonString == null) {
        print('📦 No cached feed found');
        return [];
      }
      
      // Check if cache is expired
      if (!ignoreExpiry) {
        final timestamp = _prefs!.getInt(_feedTimestampKey) ?? 0;
        final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final age = DateTime.now().difference(cachedAt);
        
        if (age.inMinutes > _cacheMaxAgeMinutes) {
          print('📦 Cache expired (${age.inMinutes} mins old)');
          return [];
        }
      }
      
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final items = jsonList.map((json) => FeedItem.fromJson(json)).toList();
      
      print('📦 Loaded ${items.length} items from local cache');
      return items;
    } catch (e) {
      print('❌ Error reading cached feed: $e');
      return [];
    }
  }
  
  /// Check if we have valid cached feed
  Future<bool> hasCachedFeed() async {
    await _ensureInitialized();
    
    final jsonString = _prefs!.getString(_feedCacheKey);
    if (jsonString == null) return false;
    
    final timestamp = _prefs!.getInt(_feedTimestampKey) ?? 0;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final age = DateTime.now().difference(cachedAt);
    
    return age.inMinutes <= _cacheMaxAgeMinutes;
  }
  
  /// Clear feed cache
  Future<void> clearCache() async {
    await _ensureInitialized();
    await _prefs!.remove(_feedCacheKey);
    await _prefs!.remove(_feedTimestampKey);
    print('📦 Feed cache cleared');
  }
  
  /// Get cache age in minutes
  Future<int> getCacheAgeMinutes() async {
    await _ensureInitialized();
    
    final timestamp = _prefs!.getInt(_feedTimestampKey) ?? 0;
    if (timestamp == 0) return -1;
    
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cachedAt).inMinutes;
  }
}
