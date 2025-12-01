import 'package:flutter/material.dart';

// 1. Convert to a StatelessWidget that uses TweenAnimationBuilder
// The function now returns this class directly.
Widget fancyAnimatedScoreWithLabel(double score, {required String label}) {
  return AnimatedScoreDisplay(score: score, label: label);
}

class AnimatedScoreDisplay extends StatelessWidget {
  final double score;
  final String label;

  const AnimatedScoreDisplay({
    super.key,
    required this.score,
    required this.label,
  });

  // Helper function to get the color based on the percentage
  Color _getProgressColor(int percent) {
    if (percent >= 80) return Colors.green.shade600;
    if (percent >= 50) return Colors.amber.shade600;
    return Colors.red.shade600;
  }

  // Helper function to get the descriptive grade (kept from before)
  String _getScoreGrade(int percent) {
    if (percent >= 90) return "Excellent";
    if (percent >= 70) return "Very Good";
    if (percent >= 50) return "Good";
    if (percent >= 30) return "Fair";
    return "Poor";
  }

  @override
  Widget build(BuildContext context) {
    int targetPercent = (score * 10).round();
    Color baseColor = _getProgressColor(targetPercent);
    Color backgroundColor = baseColor.withOpacity(0.1);

    return Container(
      width: double.infinity,
      // Outer Container Styling (Kept from previous version)
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Score Circle and Text (Animated using TweenAnimationBuilder)
          // The animation runs whenever the 'score' input changes.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: score),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double currentScore, Widget? child) {
              final currentPercent = (currentScore * 10).round();
              final currentColor = _getProgressColor(currentPercent);
              final progressValue = currentScore / 10; // 0.0 to 1.0

              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    // 2. Add Gradient to the Progress Indicator
                    child: Container(
                      padding: const EdgeInsets.all(
                        4,
                      ), // For the visual border/stroke
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Create a gradient border that is thicker than the indicator itself
                        border: Border.all(
                          color: Colors.grey.shade200, // Background color
                          width: 8,
                        ),
                      ),
                      // This CustomPaint replaces CircularProgressIndicator for a true gradient
                      child: CustomPaint(
                        painter: _GradientCircularProgressPainter(
                          progress: progressValue,
                          strokeWidth: 8, // Set stroke width here
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomRight,
                            colors: [
                              currentColor.withOpacity(0.8),
                              currentColor,
                              currentColor.darken(
                                0.1,
                              ), // Custom extension to darken
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The score text inside the circle
                  FittedBox(
                    fit: BoxFit.contain,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        "$currentPercent%",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: currentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(width: 15),

          // Label Column (Updated to use animated values)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              // Use the target percent for the grade to prevent the grade from flickering
              Text(
                _getScoreGrade(targetPercent),
                style: TextStyle(
                  fontSize: 14,
                  color: baseColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------------
// Custom Painter for Gradient Progress Indicator
// -------------------------------------------------------------------------

class _GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Gradient gradient;

  _GradientCircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0.0, 0.0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw the background track (optional, but good practice if not using a border)
    // final backgroundPaint = Paint()
    //   ..color = Colors.grey.shade200
    //   ..strokeCap = StrokeCap.round
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = strokeWidth;
    // canvas.drawCircle(center, radius, backgroundPaint);

    // 2. Draw the gradient arc
    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeCap = StrokeCap
          .round // This gives a nice rounded end to the progress bar!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Start at -90 degrees (top) and sweep for `progress` fraction of 360 degrees
    canvas.drawArc(
      rect.deflate(strokeWidth / 2), // Adjust rect to account for stroke width
      -90 * (3.1415926535 / 180), // Start angle in radians (-π/2)
      360 * progress * (3.1415926535 / 180), // Sweep angle
      false, // Center
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.gradient != gradient;
  }
}

// -------------------------------------------------------------------------
// Helper Extension to darken the color for a better gradient
// -------------------------------------------------------------------------

extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final newLightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }
}
