import 'package:flutter/material.dart';

// Define the primary green color
const Color primaryGreen = Color(0xFF1A8927);

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Use Stack to layer the centered content and the bottom button
      body: Stack(
        children: [
          // 1. Centered Content (Icon, Title, Description)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Icon (The 'F' logo) ---
                  Image.asset('assets/icon2.png'),
                  const SizedBox(height: 30),

                  // --- Title ---
                  const Text(
                    'You\'re all set!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // --- Description ---
                  const Text(
                    'We\'ve built your personalized recommendations. Get ready to discover shows you\'ll actually finish.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Fixed Bottom Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomButton(context),
          ),
        ],
      ),
    );
  }

  // Helper widget for the styled app logo
  Widget _buildAppLogo() {
    // Note: The logo in the image is a custom vector/asset.
    // This is a placeholder using a custom drawing style.
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: CustomPaint(
        painter: LogoPainter(), // Custom painter for the 'F' design
        child: const Center(
          child: Icon(Icons.play_arrow, color: primaryGreen, size: 24),
        ),
      ),
    );
  }

  // Helper widget for the bottom button
  Widget _buildBottomButton(BuildContext context) {
    return Container(
      // FIX: Removed 'color: Colors.white,' from here
      padding: EdgeInsets.only(
        left: 25.0,
        right: 25.0,
        top: 20.0,
        bottom:
            MediaQuery.of(context).padding.bottom + 20, // Account for safe area
      ),
      decoration: BoxDecoration(
        // FIXED: Moved color property inside BoxDecoration
        color: Colors.white, // White background for the safe area
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: () {
            // Navigate to the main application home screen
            print('Navigating to Home Screen');
            Navigator.of(context).pushNamedAndRemoveUntil(
              'homepage', // The route name you want to go to
              (Route<dynamic> route) =>
                  false, // This predicate ensures ALL previous routes are removed
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Start Watching',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Custom Painter for the Stylized 'F' Logo ---
class LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // A simplified path for the F shape outlines
    final Path path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.25)
      ..lineTo(size.width * 0.75, size.height * 0.25)
      ..lineTo(size.width * 0.75, size.height * 0.40)
      ..lineTo(size.width * 0.40, size.height * 0.40)
      ..lineTo(size.width * 0.40, size.height * 0.75)
      ..lineTo(size.width * 0.25, size.height * 0.75)
      ..close();

    // Rotate and draw the path to match the image's perspective
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.1); // Small angle to match the image perspective
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// void main() {
//   runApp(const MaterialApp(home: CompletionScreen()));
// }
