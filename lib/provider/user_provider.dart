import 'dart:io';
import 'package:finishd/Model/user_model.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/services/storage_service.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:finishd/services/user_service.dart';
import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();
  final UserPreferencesService _preferencesService = UserPreferencesService();

  UserModel? _currentUser;
  UserPreferences? _userPreferences;
  Set<String> _followingIds = {};
  bool _isLoading = false;
  bool _followingLoaded = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  UserPreferences? get userPreferences => _userPreferences;
  Set<String> get followingIds => _followingIds;
  bool get isLoading => _isLoading;
  bool get followingLoaded => _followingLoaded;
  String? get error => _error;

  // Fetch current user data
  Future<void> fetchCurrentUser(String uid) async {
    _isLoading = true;
    _error = null; // Reset error
    notifyListeners();

    try {
      _currentUser = await _userService.getUser(uid);
      if (_currentUser == null) {
        throw Exception('User not found');
      }
      _userPreferences = await _preferencesService.getUserPreferences(uid);
      // Fetch following IDs with cache (avoid Firestore read on startup)
      final list = await _userService.getFollowingCached(uid);
      _followingIds = list.toSet();
      _followingLoaded = true;
    } catch (e) {
      print('Error fetching current user: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? firstName,
    String? lastName,
    String? username,
    String? bio,
    String? description,
    File? imageFile,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      String profileImageUrl = _currentUser?.profileImage ?? '';

      if (imageFile != null) {
        profileImageUrl = await _storageService.uploadProfileImage(
          uid,
          imageFile,
        );
      }

      UserModel updatedUser = _currentUser!.copyWith(
        firstName: firstName,
        lastName: lastName,
        username: username,
        bio: bio,
        description: description,
        profileImage: profileImageUrl,
      );

      await _userService.updateUser(updatedUser);
      _currentUser = updatedUser;
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Follow user
  Future<void> followUser(String targetUid) async {
    if (_currentUser == null) {
      throw Exception('User not logged in. Please log in to follow users.');
    }

    try {
      await _userService.followUser(_currentUser!.uid, targetUid);
      // Optimistically update local state or re-fetch
      _currentUser = _currentUser!.copyWith(
        followingCount: _currentUser!.followingCount + 1,
      );
      _followingIds.add(targetUid);
      notifyListeners();
    } catch (e) {
      print('Error following user: $e');
      rethrow;
    }
  }

  // Unfollow user
  Future<void> unfollowUser(String targetUid) async {
    if (_currentUser == null) {
      throw Exception('User not logged in. Please log in to unfollow users.');
    }

    try {
      await _userService.unfollowUser(_currentUser!.uid, targetUid);
      // Optimistically update local state or re-fetch
      _currentUser = _currentUser!.copyWith(
        followingCount: _currentUser!.followingCount - 1,
      );
      _followingIds.remove(targetUid);
      notifyListeners();
    } catch (e) {
      print('Error unfollowing user: $e');
      rethrow;
    }
  }

  // Check if following a user (local check)
  bool isFollowing(String targetUid) {
    return _followingIds.contains(targetUid);
  }

  // Ensure following IDs are loaded
  Future<void> ensureFollowingLoaded(String uid) async {
    if (_followingLoaded) return;
    try {
      final list = await _userService.getFollowingCached(uid);
      _followingIds = list.toSet();
      _followingLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error ensuring following loaded: $e');
    }
  }
}
