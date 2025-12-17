import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final String text;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.onTap,
    this.text = "Get Started",
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, // Takes full width of the parent
        height: 55, // Fixed height for the pill shape
        decoration: BoxDecoration(
          // The Gradient: Lighter Green on top, Darker on bottom
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 28, 149, 43), // Lighter Green (Top)
              Color.fromARGB(255, 1, 136, 18), // Darker Green (Bottom)
            ],
          ),
          borderRadius: BorderRadius.circular(10), // Fully rounded corners
          boxShadow: [
            // Adds the subtle shadow below the button
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const LogoLoadingScreen()
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600, // Semi-bold looks best here
                  ),
                ),
        ),
      ),
    );
  }
}
