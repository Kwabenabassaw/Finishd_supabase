import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryText;

  const ErrorDialog({
    Key? key,
    this.title = 'Error Occurred',
    this.message = 'Something went wrong. Please try again.',
    required this.onRetry,
    this.retryText = 'Retry',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Custom colors based on the design request (Dark theme + Green accent)
    // We should try to use Theme.of(context) where possible, but the design is specific.
    final backgroundColor = const Color(0xFF1E1E1E); // Dark Grey/Black
    final accentGreen = const Color(0xFF2ECC71); // Bright Green
    final iconBgColor = const Color(0xFF2C2C2C); // Slightly lighter circle

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Stack
            SizedBox(
              height: 100,
              width: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Main Dark Circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Green Octagon/Icon
                  Icon(
                    Icons.gpp_maybe_rounded, // Octagon-like with exclamation
                    color: accentGreen,
                    size: 48,
                  ),
                  // Floating minimal bubble (Top Right)
                  Positioned(
                    top: 10,
                    right: 15,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentGreen.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.priority_high_rounded,
                        color: Colors.black,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Retry Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGreen,
                  foregroundColor: Colors.black, // Dark text on green
                  elevation: 8,
                  shadowColor: accentGreen.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      retryText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Static helper to show the dialog
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    required VoidCallback onRetry,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ErrorDialog(
        title: title ?? 'Error Occurred',
        message: message ?? 'Something went wrong. Please try again.',
        onRetry: () {
          Navigator.of(context).pop(); // Close dialog
          onRetry(); // Trigger retry
        },
      ),
    );
  }
}
