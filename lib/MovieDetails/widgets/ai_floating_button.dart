import 'package:flutter/material.dart';

class AiFloatingActionButton extends StatefulWidget {
  final VoidCallback onPressed;

  const AiFloatingActionButton({super.key, required this.onPressed});

  @override
  State<AiFloatingActionButton> createState() => _AiFloatingActionButtonState();
}

class _AiFloatingActionButtonState extends State<AiFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF4ADE80,
                ).withOpacity(0.3 * (_pulseAnimation.value - 1.0) * 5),
                blurRadius: 15,
                spreadRadius: 5 * (_pulseAnimation.value - 1.0) * 5,
              ),
            ],
          ),
          child: Transform.scale(
            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.5,
            child: FloatingActionButton(
              onPressed: widget.onPressed,
              backgroundColor: const Color(0xFF4ADE80),
              child: const Icon(
                Icons.psychology,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }
}
