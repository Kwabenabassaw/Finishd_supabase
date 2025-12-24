import 'package:flutter/material.dart';
import 'package:finishd/Widget/emotion_rating_slider.dart';

class RatingActionButton extends StatefulWidget {
  final int initialRating;
  final Function(int) onRatingChanged;
  final VoidCallback? onTap;

  const RatingActionButton({
    super.key,
    required this.initialRating,
    required this.onRatingChanged,
    this.onTap,
  });

  @override
  State<RatingActionButton> createState() => _RatingActionButtonState();
}

class _RatingActionButtonState extends State<RatingActionButton>
    with SingleTickerProviderStateMixin {
  late int _currentRating;
  late AnimationController _pulseController;

  final List<String> _emojis = ['😡', '😕', '😐', '🙂', '🤩'];

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (_currentRating == 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RatingActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      setState(() {
        _currentRating = widget.initialRating;
      });
      if (_currentRating == 0) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showRatingPopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        content: EmotionRatingSlider(
          initialRating: _currentRating,
          onRatingChanged: (rating) {
            widget.onRatingChanged(rating);
            setState(() {
              _currentRating = rating;
            });
            if (_currentRating > 0) {
              _pulseController.stop();
            }
            // Small delay for the user to see the selection before closing
            Future.delayed(const Duration(milliseconds: 300), () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap ?? _showRatingPopup,
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 1.1).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        ),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: _currentRating == 0
                ? Border.all(
                    color: const Color(0xFF4ADE80).withOpacity(0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Center(
            child: _currentRating == 0
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_reaction_outlined,
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '?',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _emojis[_currentRating - 1],
                    style: const TextStyle(fontSize: 24),
                  ),
          ),
        ),
      ),
    );
  }
}
