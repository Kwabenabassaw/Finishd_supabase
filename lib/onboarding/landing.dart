import 'package:flutter/material.dart';
import 'dart:async';

// --- Netflix-Style Animated Image Background ---
class ImageCardBackground extends StatefulWidget {
  const ImageCardBackground({super.key});

  @override
  State<ImageCardBackground> createState() => _ImageCardBackgroundState();
}

class _ImageCardBackgroundState extends State<ImageCardBackground>
    with TickerProviderStateMixin {
  // List of images from assets/landing folder
  final List<String> _images = [
    'assets/landing/Avatar.webp',
    'assets/landing/StrangerThings.webp',
    'assets/landing/House.webp',
    'assets/landing/Badlands.jpg',
  ];

  int _currentIndex = 0;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Scale animation - Netflix-style zoom from center
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    // Fade animation for smooth transitions
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Scale from 0.8 to 1.15 - creates the "pop out and zoom forward" effect
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.15).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );

    // Fade in animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start the first animation
    _startAnimation();

    // Timer to cycle through images
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _transitionToNextImage();
    });
  }

  void _startAnimation() {
    _scaleController.reset();
    _fadeController.reset();
    _fadeController.forward();
    _scaleController.forward();
  }

  void _transitionToNextImage() async {
    // Fade out current image
    await _fadeController.reverse();

    // Change to next image
    setState(() {
      _currentIndex = (_currentIndex + 1) % _images.length;
    });

    // Start new animation sequence
    _startAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      height: screenHeight * 0.75,
      color: Colors.black,
      child: Stack(
        children: [
          // Background glow effect
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        Colors.grey.shade900.withOpacity(
                          0.9 * _fadeAnimation.value,
                        ),
                        Colors.black,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Main animated image
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      width: screenWidth * 0.85,
                      height: screenHeight * 0.65,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.6 * _fadeAnimation.value,
                            ),
                            blurRadius: 30 * _scaleAnimation.value,
                            spreadRadius: 10 * (_scaleAnimation.value - 0.8),
                          ),
                          // Subtle glow effect
                          BoxShadow(
                            color: const Color(
                              0xFF1A8927,
                            ).withOpacity(0.15 * _fadeAnimation.value),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          _images[_currentIndex],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Floating smaller posters in background for depth
          ..._buildFloatingPosters(screenWidth, screenHeight),

          // Bottom gradient fade to blend with content below
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.25,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingPosters(double screenWidth, double screenHeight) {
    // Create smaller floating posters that add depth
    final List<Map<String, dynamic>> posterConfigs = [
      {'left': -30.0, 'top': 80.0, 'size': 0.25, 'delay': 0},
      {'right': -20.0, 'top': 120.0, 'size': 0.22, 'delay': 1},
      {'left': 20.0, 'bottom': 180.0, 'size': 0.18, 'delay': 2},
      {'right': 30.0, 'bottom': 220.0, 'size': 0.20, 'delay': 3},
    ];

    return posterConfigs.asMap().entries.map((entry) {
      final int index = entry.key;
      final config = entry.value;
      final int imageIndex = (_currentIndex + index + 1) % _images.length;

      return AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
        builder: (context, child) {
          // Staggered scale for depth effect
          final staggeredScale = 0.7 + (_scaleAnimation.value - 0.8) * 0.5;
          final staggeredOpacity = (_fadeAnimation.value * 0.4).clamp(0.0, 0.4);

          return Positioned(
            left: config['left'] as double?,
            right: config['right'] as double?,
            top: config['top'] as double?,
            bottom: config['bottom'] as double?,
            child: Transform.scale(
              scale: staggeredScale,
              child: Opacity(
                opacity: staggeredOpacity,
                child: Container(
                  width: screenWidth * (config['size'] as double),
                  height: screenHeight * (config['size'] as double) * 1.4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(_images[imageIndex], fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }
}
// --- End Netflix-Style Animation ---

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the primary green color from the image

    return Scaffold(
      // Ensure the content goes all the way to the top edge (under the status bar)
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Image Background Layer (Covers the upper half)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ImageCardBackground(),
          ),

          // 2. Gradient/Fade Overlay (To darken the images below the text)
          // This creates a smooth transition from the images to the white background
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0), // Fades out at the top
                    Colors.black.withOpacity(
                      0.1,
                    ), // Becomes white at the bottom
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),

          // 3. Content Layer (Logo, Text, Button)
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40.0,
                  vertical: 60.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Logo (The 'F' icon) ---
                    
                    Padding(
                      padding: const EdgeInsets.only(top: 150.0),
                      child: Image.asset('assets/finishdlogo4.png', fit: BoxFit.contain,
                      height: 50,
                      width: 50,
                    
                      ),
                    ),

                  

                    // --- Title ---
                    const Text(
                      'TV, but social.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // --- Description ---
                    const Text(
                      'Track your shows. See what your friends are watching. Discover what to watch next.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 1.4),
                    ),

                    const SizedBox(height: 50),

                    // --- Get Started Button ---
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/signup');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A8927),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0, // Removes shadow
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Padding for the bottom safe area (home indicator)
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
