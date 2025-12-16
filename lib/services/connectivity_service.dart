import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to check and monitor internet connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Check if device has any network connection (WiFi, mobile, ethernet)
  Future<bool> hasNetworkConnection() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Check if device has actual internet access by pinging a reliable host
  /// This is more reliable than just checking connectivity type
  Future<bool> hasInternetAccess() async {
    // First check basic connectivity
    if (!await hasNetworkConnection()) {
      return false;
    }

    // Then verify actual internet access
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return false;
    }
  }

  /// Get current connectivity type as a user-friendly string
  Future<String> getConnectionType() async {
    final result = await _connectivity.checkConnectivity();

    if (result.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    } else if (result.contains(ConnectivityResult.mobile)) {
      return 'Mobile Data';
    } else if (result.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    } else if (result.contains(ConnectivityResult.vpn)) {
      return 'VPN';
    } else {
      return 'No Connection';
    }
  }
}
