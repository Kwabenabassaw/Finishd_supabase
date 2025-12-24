import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmotionRatingSlider extends StatefulWidget {
  final int initialRating;
  final Function(int) onRatingChanged;

  const EmotionRatingSlider({
    super.key,
    required this.initialRating,
    required this.onRatingChanged,
  });

  @override
  State<EmotionRatingSlider> createState() => _EmotionRatingSliderState();
}

class _EmotionRatingSliderState extends State<EmotionRatingSlider> {
  late double _currentRating;

  final List<String> _emojis = ['😡', '😕', '😐', '🙂', '🤩'];
  final List<String> _labels = [
    'Hated it',
    'Didn\'t like it',
    'It was okay',
    'Liked it',
    'Loved it!',
  ];

  @override
  void initState() {
    super.initState();
    // Use 0 as "no rating", and map 1-5
    _currentRating = widget.initialRating.toDouble();
  }

  @override
  void didUpdateWidget(EmotionRatingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      setState(() {
        _currentRating = widget.initialRating.toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              final step = index + 1;
              final isSelected = step == _currentRating.round();
              final isNoRating = _currentRating == 0;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    _updateRating(step.toDouble());
                    widget.onRatingChanged(step);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    child: Column(
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.4 : (isNoRating ? 1.0 : 0.8),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          child: Text(
                            _emojis[index],
                            style: TextStyle(
                              fontSize: 32,
                              shadows: isSelected
                                  ? [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isSelected)
                          AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _getRatingColor(step),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: _getRatingColor(
                _currentRating.round(),
              ).withOpacity(0.4),
              inactiveTrackColor: theme.dividerColor.withOpacity(0.1),
              thumbColor: _currentRating == 0
                  ? Colors.grey
                  : _getRatingColor(_currentRating.round()),
              overlayColor: _getRatingColor(
                _currentRating.round(),
              ).withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 0),
            ),
            child: Slider(
              value: _currentRating == 0 ? 3.0 : _currentRating,
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _currentRating = value;
                });
              },
              onChangeEnd: (value) {
                widget.onRatingChanged(value.round());
              },
            ),
          ),
          Text(
            _currentRating == 0
                ? 'Your reaction'
                : _labels[_currentRating.round() - 1],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _currentRating == 0
                  ? theme.textTheme.bodySmall?.color
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _updateRating(double value) {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentRating = value;
    });
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.lightGreen;
      case 5:
        return const Color(0xFF4ADE80);
      default:
        return Colors.grey;
    }
  }
}
