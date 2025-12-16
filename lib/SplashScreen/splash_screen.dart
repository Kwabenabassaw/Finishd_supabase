import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/services/connectivity_service.dart';
import 'package:finishd/SplashScreen/no_internet_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isCheckingConnectivity = true;
  bool _hasInternet = false;
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();

    // Setup fade-in animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Start connectivity check and animation in parallel
    _checkConnectivityAndNavigate();
  }

  Future<void> _checkConnectivityAndNavigate() async {
    // Wait for minimum splash display time (for branding)
    final minDisplayFuture = Future.delayed(const Duration(seconds: 3));

    // Check connectivity
    final hasInternet = await _connectivityService.hasInternetAccess();

    // Wait for minimum display time to complete
    await minDisplayFuture;

    if (mounted) {
      setState(() {
        _isCheckingConnectivity = false;
        _hasInternet = hasInternet;
        _animationComplete = true;
      });

      if (hasInternet) {
        _navigateBasedOnAuth();
      }
      // If no internet, the build method will show NoInternetScreen
    }
  }

  void _navigateBasedOnAuth() {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser != null) {
      Navigator.pushReplacementNamed(context, 'homepage');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _handleRetry() {
    setState(() {
      _isCheckingConnectivity = true;
    });
    _checkConnectivityAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show No Internet screen if connectivity check failed
    if (_animationComplete && !_hasInternet && !_isCheckingConnectivity) {
      return NoInternetScreen(onRetry: _handleRetry);
    }

    // Show splash screen during loading and connectivity check
    return Scaffold(
      backgroundColor: const Color(0xFF1A8927),
      body: FadeTransition(
        opacity: _animation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon2.png'),
              if (_isCheckingConnectivity && _animationComplete) ...[
                const SizedBox(height: 30),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Checking connection...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
