import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Primary brand color used across the onboarding screens
const Color primaryGreen = Color(0xFF1A8927);

/// Custom Widget for the Labeled Text Fields with password toggle support
class LabeledTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final bool isPassword;
  final TextEditingController? controller;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.controller,
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            suffixIcon: widget.isPassword
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Custom Widget for the Log In / Sign Up Toggle with haptic feedback
class ToggleButtonRow extends StatelessWidget {
  final bool isLoginActive;

  const ToggleButtonRow({super.key, this.isLoginActive = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          // Log In Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isLoginActive
                      ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isLoginActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isLoginActive
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          // Sign Up Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushReplacementNamed(context, '/signup');
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !isLoginActive
                      ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isLoginActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: !isLoginActive
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard onboarding bottom button with proper SafeArea handling
class OnboardingBottomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? skipText;
  final VoidCallback? onSkip;

  const OnboardingBottomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.skipText,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 25.0,
        right: 25.0,
        top: 15.0,
        bottom: MediaQuery.of(context).padding.bottom + 15,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                disabledBackgroundColor: primaryGreen.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          if (skipText != null && onSkip != null) ...[
            const SizedBox(height: 15),
            TextButton(
              onPressed: onSkip,
              child: Text(
                skipText!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Progress header widget for onboarding steps
class OnboardingProgressHeader extends StatelessWidget {
  final double progress;
  final int currentStep;
  final int totalSteps;

  const OnboardingProgressHeader({
    super.key,
    required this.progress,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 15),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Step $currentStep of $totalSteps',
          style: const TextStyle(
            color: primaryGreen,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
