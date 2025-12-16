import 'package:flutter/material.dart';

// --- Placeholder for your custom image background widget ---
class ImageCardBackground extends StatefulWidget {
  const ImageCardBackground({super.key});

  @override
  State<ImageCardBackground> createState() => _ImageCardBackgroundState();
}

class _ImageCardBackgroundState extends State<ImageCardBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 3), // animation duration
      vsync: this,
    );

    // Slide from right to left
    _animation = Tween<Offset>(
      begin: Offset(1.0, 1.0), // Start just outside the right
      end: Offset(0.0, 0.0), // End at original position
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward(); // Start animation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This is a simplified representation of the complex, layered image wall.
    // In a real app, you'd use Transform.rotate or a CustomPainter
    // to achieve the diagonal, overlapping effect.
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.8, // Covers top 60%
      alignment: Alignment.topCenter,
      child: Transform.translate(
        offset: const Offset(0, -30), // Move slightly up
        child: Transform.rotate(
          angle: 0, // Slight rotation for the dynamic feel
          child: SlideTransition(
            position: _animation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/Posters.png',
                  fit: BoxFit.fitHeight,
                  width: 400,
                  height: MediaQuery.of(context).size.height * 0.70,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// --- End Placeholder ---

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
                    Colors.white.withOpacity(
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
                    Image.asset('assets/icon2.png', fit: BoxFit.contain),

                    const SizedBox(height: 30),

                    // --- Title ---
                    const Text(
                      'TV, but social.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // --- Description ---
                    const Text(
                      'Track your shows. See what your friends are watching. Discover what to watch next.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        height: 1.4,
                      ),
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
