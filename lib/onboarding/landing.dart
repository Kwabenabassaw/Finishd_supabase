import 'package:finishd/onboarding/widgets/button.dart';
import 'package:flutter/material.dart';
// Needed for the rotation angle

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Setup your images
    final List<String> images1 = [
      'assets/landing/Merv.webp',
      'assets/landing/Witcher.webp',
      'assets/landing/IT.webp',
      'assets/landing/StrangerThings.webp',
    ];
    final List<String> images2 = [
      'assets/landing/Badlands.jpg',
      'assets/landing/Slohorses.webp',
      'assets/landing/Homeland.webp',
      'assets/landing/Avatar.webp',
    ];
    final List<String> images3 = [
      'assets/landing/morningshow.webp',
      'assets/landing/StrangerThings.webp',
      'assets/landing/Merv.webp',
      'assets/landing/Witcher.webp',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // BACKGROUND: The Tilted Grid
          // We use Positioned with negative values to make the grid bigger
          // than the screen. This ensures that when we rotate it,
          // we don't see empty white corners.
          Positioned(
            top: -100,
            bottom: -100,
            left: -100,
            right: -100,
            child: Transform.rotate(
              angle: -0.15, // Roughly -8 degrees (The "Tilt")
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column 1
                  Expanded(
                    child: InfiniteVerticalScroll(
                      images: images1,
                      speed: 30, // Slow
                    ),
                  ),
                  const SizedBox(width: 15), // Gap
                  // Column 2 (Moves opposite direction)
                  Expanded(
                    child: InfiniteVerticalScroll(
                      images: images2,
                      speed: 50, // Faster
                      reverse: true, // Moves Down
                    ),
                  ),
                  const SizedBox(width: 15), // Gap
                  // Column 3
                  Expanded(
                    child: InfiniteVerticalScroll(
                      images: images3,
                      speed: 35, // Medium
                    ),
                  ),
                ],
              ),
            ),
          ),

          // FOREGROUND: Gradient (To fade the bottom)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0), // Keep middle clear
                    Colors.white.withOpacity(0.8),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // TEXT CONTENT
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Column(

              children: [
                Image.asset('assets/icon2.png', height: 100, width: 100,),
                const SizedBox(height: 15),
                const Text(
                  "TV, but social.",
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold ,color:Color.fromARGB(255, 30, 30, 30 ),),
                ),
       
                const Text(
                  "Track your shows. See what your friends are watching.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color.fromARGB(255,126, 132, 137), fontSize: 18),
                ),
                const SizedBox(height: 29),
                PrimaryButton(onTap:(){
                  Navigator.pushReplacementNamed(context, '/signup');
                }, text: "Get Started"),
              ],
            ),
          

          ),
        ],

      ),
    );
  }
}

// --- THE VERTICAL SCROLL WIDGET ---
class InfiniteVerticalScroll extends StatefulWidget {
  final List<String> images;
  final double speed;
  final bool reverse;

  const InfiniteVerticalScroll({
    super.key,
    required this.images,
    this.speed = 30.0,
    this.reverse = false,
  });

  @override
  State<InfiniteVerticalScroll> createState() => _InfiniteVerticalScrollState();
}

class _InfiniteVerticalScrollState extends State<InfiniteVerticalScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final double _itemHeight = 250.0; // Height of card + margin

  @override
  void initState() {
    super.initState();
    double totalHeight = widget.images.length * _itemHeight;
    int durationSeconds = (totalHeight / widget.speed).round();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSeconds),
    );

    double start = widget.reverse ? -totalHeight : 0.0;
    double end = widget.reverse ? 0.0 : -totalHeight;

    _animation = Tween<double>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        maxHeight: double.infinity,
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animation.value),
              child: Column(children: [..._buildList(), ..._buildList()]),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    return widget.images.map((imgUrl) {
      return Container(
        height: 250,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Shadow to make them pop off the white background
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: DecorationImage(
            image: AssetImage(imgUrl),

            fit: BoxFit.cover,
          ),
        ),
      );
    }).toList();
  }
}
