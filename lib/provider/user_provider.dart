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
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  UserPreferences? get userPreferences => _userPreferences;
  bool get isLoading => _isLoading;

  // Fetch current user data
  Future<void> fetchCurrentUser(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _userService.getUser(uid);
      _userPreferences = await _preferencesService.getUserPreferences(uid);
    } catch (e) {
      print('Error fetching current user: $e');
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
      throw e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Follow user
  Future<void> followUser(String targetUid) async {
    if (_currentUser == null) return;

    try {
      await _userService.followUser(_currentUser!.uid, targetUid);
      // Optimistically update local state or re-fetch
      _currentUser = _currentUser!.copyWith(
        followingCount: _currentUser!.followingCount + 1,
      );
      notifyListeners();
    } catch (e) {
      print('Error following user: $e');
      throw e;
    }
  }

  // Unfollow user
  Future<void> unfollowUser(String targetUid) async {
    if (_currentUser == null) return;

    try {
      await _userService.unfollowUser(_currentUser!.uid, targetUid);
      // Optimistically update local state or re-fetch
      _currentUser = _currentUser!.copyWith(
        followingCount: _currentUser!.followingCount - 1,
      );
      notifyListeners();
    } catch (e) {
      print('Error unfollowing user: $e');
      throw e;
    }
  }
}
