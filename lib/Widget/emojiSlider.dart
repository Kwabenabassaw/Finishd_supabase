import 'package:flutter/material.dart';

void showEmojiSlider(BuildContext context) {
  // List of slider values to maintain the state of each slider.
  List<double> sliderValues = [0, 2, 4, 2, 0];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              height: 300,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(sliderValues.length, (index) {
                  return RotatedBox(
                    quarterTurns: 3, // Rotate to make it vertical
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.green,
                        inactiveTrackColor: Colors.green.withOpacity(0.2),
                        trackShape: const RoundedRectSliderTrackShape(),
                        trackHeight: 8.0,
                        thumbShape: _EmojiThumbShape(),
                        thumbColor: Colors.transparent, // Hide default thumb
                        overlayColor: Colors.green.withAlpha(32),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 28.0,
                        ),
                      ),
                      child: Slider(
                        value: sliderValues[index],
                        min: 0,
                        max: 4,
                        divisions: 4,
                        onChanged: (value) {
                          setState(() {
                            sliderValues[index] = value;
                          });
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      );
    },
  );
}

class _EmojiThumbShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(40, 40);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    TextPainter? labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    TextDirection textDirection = TextDirection.ltr,
    double value = 0.0,
    double textScaleFactor = 1.0,
    Size sizeWithOverflow = const Size(40, 40),
  }) {
    final Canvas canvas = context.canvas;

    // Determine the emoji based on the slider's value.
    // The values are 0, 1, 2, 3, 4.
    String emoji;
    if (value < 0.25) {
      emoji = "🥴"; // Bottom
    } else if (value > 0.75) {
      emoji = "😍"; // Top
    } else {
      emoji = "💚"; // Middle
    }

    // Draw the emoji on the canvas.
    final TextSpan span = TextSpan(
      text: emoji,
      style: const TextStyle(fontSize: 35),
    );

    final TextPainter textPainter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // RotatedBox rotates the canvas, so we need to counter-rotate the text.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-1.5708); // Rotate back 90 degrees (in radians)
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
    canvas.restore();
  }
}
