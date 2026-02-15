import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/services/connectivity_service.dart';
import 'package:finishd/services/moderation_listener_service.dart';
import 'package:finishd/services/moderation_notification_handler.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/SplashScreen/no_internet_screen.dart';
import 'package:finishd/screens/moderation_block_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

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

    // Remove the native splash screen as soon as the Flutter app starts
    FlutterNativeSplash.remove();

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

  Future<void> _navigateBasedOnAuth() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser != null) {
      final userId = authService.currentUser!.id;

      // Check moderation status BEFORE allowing into app
      final moderationStatus = await authService.checkUserModerationStatus(
        userId,
      );

      if (moderationStatus != null && mounted) {
        // User is banned or suspended - show block screen with appeal option
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ModerationBlockScreen(
              isBanned: moderationStatus.isBanned,
              reason: moderationStatus.reason,
              daysRemaining: moderationStatus.daysRemaining,
            ),
          ),
        );
        return;
      }

      // Start real-time moderation listener for active users
      ModerationListenerService.instance.startListening();

      // Start moderation notification handler for warnings
      ModerationNotificationHandler.instance.startListening();

      // User is clear - initialize and proceed
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).fetchCurrentUser(userId);
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
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: FadeTransition(
        opacity: _animation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/Finishdlogo.png', width: 200, height: 200),
              if (_isCheckingConnectivity) ...[
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
