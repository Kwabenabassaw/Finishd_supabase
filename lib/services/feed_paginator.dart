import '../db/objectbox/feed_entities.dart';
import 'dart:math';

/// Feed Paginator - Handles windowed rendering of feed items.
///
/// Why: TikTok-style feeds shouldn't load 100+ items upfront.
/// This enables progressive rendering from ObjectBox.
///
/// Usage:
/// ```dart
/// final paginator = FeedPaginator();
/// final window = paginator.getWindow(allItems);
/// // ... user scrolls ...
/// paginator.loadNextWindow();
/// final nextWindow = paginator.getWindow(allItems);
/// ```
class FeedPaginator {
  /// Number of items per window
  static const int windowSize = 20;

  /// Current window index
  int _currentWindow = 0;

  /// Get items for the current window.
  ///
  /// Returns items from [_currentWindow * windowSize] to
  /// [(_currentWindow + 1) * windowSize].
  List<CachedFeedItem> getWindow(List<CachedFeedItem> allItems) {
    final startIndex = _currentWindow * windowSize;
    final endIndex = min(startIndex + windowSize, allItems.length);

    if (startIndex >= allItems.length) {
      return [];
    }

    return allItems.sublist(startIndex, endIndex);
  }

  /// Get all items up to and including current window.
  ///
  /// Use this for additive rendering (all items visible up to current position).
  List<CachedFeedItem> getAllUpToCurrentWindow(List<CachedFeedItem> allItems) {
    final endIndex = min((_currentWindow + 1) * windowSize, allItems.length);
    return allItems.sublist(0, endIndex);
  }

  /// Load the next window of items.
  void loadNextWindow() {
    _currentWindow++;
  }

  /// Reset to the first window.
  void reset() {
    _currentWindow = 0;
  }

  /// Get the current window index.
  int get currentWindowIndex => _currentWindow;

  /// Check if there are more windows to load.
  bool hasMoreWindows(int totalItems) {
    final nextStartIndex = (_currentWindow + 1) * windowSize;
    return nextStartIndex < totalItems;
  }

  /// Get total number of windows for given item count.
  int getWindowCount(int totalItems) {
    return (totalItems / windowSize).ceil();
  }

  /// Check if an index is in the current or previous windows (visible).
  bool isIndexVisible(int index) {
    return index < (_currentWindow + 1) * windowSize;
  }

  /// Get progress (0.0 to 1.0) through the feed.
  double getProgress(int totalItems) {
    if (totalItems == 0) return 0.0;
    final visibleCount = min((_currentWindow + 1) * windowSize, totalItems);
    return visibleCount / totalItems;
  }
}
