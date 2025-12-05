import 'package:flutter/material.dart';

// --- Reusable Logo Loading Screen Widget ---
// This widget handles the logo animation (scaling in and out) and can be easily
// dropped into your application when content is being loaded.
class LogoLoadingScreen extends StatefulWidget {
  // A key is optional, but good practice for widgets.
  const LogoLoadingScreen({super.key});

  @override
  State<LogoLoadingScreen> createState() => _LogoLoadingScreenState();
}

// We use SingleTickerProviderStateMixin to manage the AnimationController,
// which is essential for smooth, frame-rate independent animations.
class _LogoLoadingScreenState extends State<LogoLoadingScreen>
    with SingleTickerProviderStateMixin {
  
  // The controller manages the animation's timing and state.
  late AnimationController _animationController;
  
  // The animation object maps the controller's value (0.0 to 1.0) to a scale factor (0.9 to 1.1).
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize the controller
    _animationController = AnimationController(
      vsync: this, // 'this' refers to the TickerProvider
      duration: const Duration(milliseconds: 300), // 1 second for one cycle
    );

    // 2. Define the scale range (Tween)
    // The logo will smoothly scale between 90% (0.9) and 110% (1.1) of its original size.
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      // Use a curved animation for a smoother, more natural "breathing" effect.
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 3. Start the animation and make it loop indefinitely
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    // IMPORTANT: Always dispose of the controller to prevent memory leaks.
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The background should be "off" (dark/transparent). We'll use a dark background
    // for high contrast with the logo, but you can set the color to Colors.transparent
    // if you want to see the underlying content.
    return Container(
      color: Colors.transparent, // Dark background for the loading screen
      child: Center(
        // AnimatedBuilder rebuilds the widget tree whenever the animation value changes.
        // This is highly efficient because it only rebuilds the part that needs to change (the logo).
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            // Transform.scale applies the scaling factor from the animation.
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: SizedBox(
                // Constrain the size of the logo container
                width: 250,
                height: 100,
                child: Image.asset(
                  'assets/Finishdlogo.png', // The path to your renamed logo file
                  fit: BoxFit.contain, // Ensures the entire logo is visible
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}