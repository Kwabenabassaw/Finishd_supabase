/// Voting API Client
///
/// Handles communication with the Node.js voting backend.
/// This is the ONLY place that makes vote API calls.
///
/// IMPORTANT: The client no longer updates Firestore counters directly.
/// All vote operations go through the backend.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Result of a vote operation
class VoteResult {
  final String postId;
  final int upvotes;
  final int downvotes;
  final int score;
  final int? userVote; // 1, -1, or null

  VoteResult({
    required this.postId,
    required this.upvotes,
    required this.downvotes,
    required this.score,
    this.userVote,
  });

  factory VoteResult.fromJson(Map<String, dynamic> json) {
    return VoteResult(
      postId: json['postId'] as String,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      userVote: json['userVote'] as int?,
    );
  }

  @override
  String toString() {
    return 'VoteResult(postId: $postId, upvotes: $upvotes, downvotes: $downvotes, score: $score, userVote: $userVote)';
  }
}

/// API Client for the voting backend
class VotingApiClient {
  // Production backend URL (Koyeb)
  static const String _baseUrl =
      'https://pythonbackend-nu.vercel.app';

  final http.Client _client;

  VotingApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Get Firebase ID token for authentication
  Future<String?> _getAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _log('⚠️ No user logged in - cannot get auth token');
        return null;
      }

      final token = await user.getIdToken();
      _log('✅ Got Firebase ID token');
      return token;
    } catch (e) {
      _log('❌ Failed to get Firebase ID token: $e');
      return null;
    }
  }

  /// Log messages (only in debug mode)
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[VotingAPI] $message');
    }
  }

  /// Cast a vote on a post
  ///
  /// [postId] - The post to vote on
  /// [showId] - The community/show ID (required for vote document ID)
  /// [vote] - 1 for upvote, -1 for downvote
  ///
  /// Behavior:
  /// - No existing vote → create vote
  /// - Different vote → switch vote
  /// - Same vote → remove vote (toggle off)
  Future<VoteResult> voteOnPost(String postId, int showId, int vote) async {
    _log('🗳️ Voting on post: $postId (showId: $showId) with vote: $vote');

    // Validate vote
    if (vote != 1 && vote != -1) {
      _log('❌ Invalid vote value: $vote. Must be 1 or -1');
      throw ArgumentError('Vote must be 1 or -1, got: $vote');
    }

    // Get auth token
    final token = await _getAuthToken();
    if (token == null) {
      _log('❌ Cannot vote without authentication');
      throw Exception('User not authenticated');
    }

    // For Render backend, we use the full path with postId
    final url = Uri.parse('$_baseUrl/posts/$postId/vote');
    _log('📤 POST $url');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'vote': vote, 'showId': showId}),
      );

      _log('📥 Response status: ${response.statusCode}');
      _log('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = VoteResult.fromJson(json);
        _log('✅ Vote successful: $result');
        return result;
      } else if (response.statusCode == 401) {
        _log('❌ Unauthorized - token may be expired');
        throw Exception('Unauthorized: Please sign in again');
      } else if (response.statusCode == 404) {
        _log('❌ Post not found: $postId');
        throw Exception('Post not found');
      } else {
        _log(
          '❌ Vote failed with status ${response.statusCode}: ${response.body}',
        );
        throw Exception('Vote failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      _log('❌ Network error: $e');
      throw Exception('Network error: Unable to connect to voting server');
    }
  }

  /// Get current vote counts for a post
  ///
  /// [postId] - The post to get votes for
  /// [showId] - Optional show ID for looking up user's vote
  Future<VoteResult> getPostVotes(String postId, {int? showId}) async {
    _log('📖 Getting votes for post: $postId (showId: $showId)');

    // Get auth token - required for this endpoint
    final token = await _getAuthToken();
    if (token == null) {
      _log('❌ Cannot get votes without authentication');
      throw Exception('User not authenticated');
    }

    // Build URL with optional showId query parameter
    var url = Uri.parse('$_baseUrl/posts/$postId/votes');
    if (showId != null) {
      url = url.replace(queryParameters: {'show_id': showId.toString()});
    }
    _log('📤 GET $url');

    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      _log('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VoteResult.fromJson(json);
      } else if (response.statusCode == 404) {
        throw Exception('Post not found');
      } else {
        throw Exception('Failed to get post: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      _log('❌ Network error: $e');
      throw Exception('Network error: Unable to connect to server');
    }
  }

  /// Check if the backend is reachable
  Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      _log('❌ Health check failed: $e');
      return false;
    }
  }

  /// Dispose the HTTP client
  void dispose() {
    _client.close();
  }
}
