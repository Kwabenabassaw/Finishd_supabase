import 'dart:async';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Model/movie_ratings_model.dart';
import 'package:finishd/services/ai/ai_context_builder.dart';
import 'package:finishd/services/ai/vertex_ai_service.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

class AiAssistantProvider extends ChangeNotifier {
  final VertexAiService _aiService = VertexAiService();

  String? _currentTitleId;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Rate limiting
  final List<DateTime> _messageTimestamps = [];
  static const int _maxMessagesPerMinute = 5;

  // State getters
  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  final ChatUser _aiUser = ChatUser(
    id: 'ai-assistant',
    firstName: 'Finishd',
    lastName: 'AI',
    profileImage:
        'https://firebasestorage.googleapis.com/v0/b/finishd-app.appspot.com/o/assets%2Fai_avatar.png?alt=media', // placeholder
  );

  ChatUser get aiUser => _aiUser;
  ChatUser get currentUser => _currentUser;

  late ChatUser _currentUser;
  late ChatSession _chatSession;

  AiAssistantProvider() {
    final user = FirebaseAuth.instance.currentUser;
    _currentUser = ChatUser(
      id: user?.uid ?? 'guest',
      firstName: user?.displayName ?? 'User',
    );
  }

  /// Initializes the provider for a specific movie.
  /// Clears previous history if the movie changed.
  void initForMovie(MovieDetails movie, MovieRatings ratings) {
    if (_currentTitleId == movie.id.toString()) return;

    _currentTitleId = movie.id.toString();
    _messages = [];
    _messageTimestamps.clear();

    final context = AiContextBuilder.buildMovieContext(
      movie: movie,
      ratings: ratings,
    );
    _chatSession = _aiService.startChat(movieContext: context);

    // Add initial greeting
    _messages.insert(
      0,
      ChatMessage(
        text:
            "Hello! I'm your Finishd AI Assistant for '${movie.title}'. How can I help you today?",
        user: _aiUser,
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  /// Initializes the provider for a specific TV show.
  /// Clears previous history if the show changed.
  void initForTvShow(TvShowDetails show, MovieRatings ratings) {
    if (_currentTitleId == show.id.toString()) return;

    _currentTitleId = show.id.toString();
    _messages = [];
    _messageTimestamps.clear();

    final context = AiContextBuilder.buildTvShowContext(
      show: show,
      ratings: ratings,
    );
    _chatSession = _aiService.startChat(movieContext: context);

    // Add initial greeting
    _messages.insert(
      0,
      ChatMessage(
        text:
            "Hello! I'm your Finishd AI Assistant for '${show.name}'. How can I help you today?",
        user: _aiUser,
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  /// Check if the user is rate limited.
  bool _isRateLimited() {
    final now = DateTime.now();
    _messageTimestamps.removeWhere((t) => now.difference(t).inMinutes >= 1);
    return _messageTimestamps.length >= _maxMessagesPerMinute;
  }

  /// Sends a message and handles the AI response.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isRateLimited()) {
      _messages.insert(
        0,
        ChatMessage(
          text:
              "Please slow down! You can only send $_maxMessagesPerMinute messages per minute.",
          user: _aiUser,
          createdAt: DateTime.now(),
        ),
      );
      notifyListeners();
      return;
    }

    final userMessage = ChatMessage(
      text: text,
      user: _currentUser,
      createdAt: DateTime.now(),
    );

    _messages.insert(0, userMessage);
    _messageTimestamps.add(DateTime.now());
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _aiService.sendMessage(_chatSession, text);
      final aiText = response.text ?? "I'm sorry, I couldn't process that.";

      _messages.insert(
        0,
        ChatMessage(text: aiText, user: _aiUser, createdAt: DateTime.now()),
      );

      // Truncate history (keep last 10 messages for memory efficiency)
      if (_messages.length > 10) {
        _messages = _messages.sublist(0, 10);
      }
    } catch (e) {
      _messages.insert(
        0,
        ChatMessage(
          text: "Error connecting to AI: ${e.toString()}",
          user: _aiUser,
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
