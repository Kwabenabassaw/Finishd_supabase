import 'package:flutter/foundation.dart';
import 'package:finishd/Model/actor_model.dart';
import 'package:finishd/services/actor_service.dart';

enum ActorState { initial, loading, loaded, error }

class ActorProvider extends ChangeNotifier {
  final ActorService _service = ActorService();

  ActorState _state = ActorState.initial;
  ActorState get state => _state;

  ActorModel? _actor;
  ActorModel? get actor => _actor;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Cache to prevent refetching same actor if revisited immediately
  // (Optional, simple implementation for now)

  Future<void> fetchActorDetails(int personId) async {
    _state = ActorState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _service.fetchActorDetails(personId);
      if (result != null) {
        _actor = result;
        _state = ActorState.loaded;
      } else {
        _errorMessage = 'Failed to load actor details.';
        _state = ActorState.error;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _state = ActorState.error;
    }

    notifyListeners();
  }
}
