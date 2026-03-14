import 'package:flutter/material.dart';

class AnimatedWallpaper extends StatefulWidget {
  final Widget child;
  final bool? forceDarkMode;

  const AnimatedWallpaper({
    super.key,
    required this.child,
    this.forceDarkMode,
  });

  @override
  State<AnimatedWallpaper> createState() => _AnimatedWallpaperState();
}

class _AnimatedWallpaperState extends State<AnimatedWallpaper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A slow, continuous loop
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    ); // ..repeat(); // Stopped animation per request
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine screen size for absolute positioning
    final size = MediaQuery.of(context).size;
    final isDark = widget.forceDarkMode ?? Theme.of(context).brightness == Brightness.dark;
    
    // Grid parameters
    const int rows = 6;
    const int cols = 4;
    
    // We want the icon to repeat across 10 cols and 12 rows cleanly
    final double iconWidth = size.width / cols;
    final double iconHeight = size.height / rows;
    // We add some buffer rows/cols to hide the seam during translation
    final double overflowWidth = iconWidth * 2;
    final double overflowHeight = iconHeight * 2;

    return Stack(
      children: [
        // The background color (Adaptive Mint Green)
        Container(
          color: isDark ? const Color(0xFF1A1C1A) : const Color(0xFFE2F1E1),
        ),
        
        // The animated grid
        Positioned.fill(
          child: Transform.rotate(
            angle: -0.26, // Approx -15 degrees
            child: OverflowBox(
              maxWidth: size.width * 2,
              maxHeight: size.height * 2,
              alignment: Alignment.center,
              child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 30,
                      crossAxisSpacing: 30,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: 60,
                    itemBuilder: (context, index) {
                      return Transform.translate(
                        offset: Offset( (index % 2 == 0) ? 0 : 40, 0), // Staggered look
                        child: Opacity(
                          opacity: isDark ? 0.05 : 0.08,
                          child: Center(
                            child: Stack(
                              children: [
                                // 3D-style Shadow
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: Opacity(
                                    opacity: 0.1,
                                    child: Image.asset(
                                      'assets/launcher_icon_foreground.png',
                                      width: 80,
                                      height: 80,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                // Main Logo (F-icon without background)
                                Image.asset(
                                  'assets/launcher_icon_foreground.png',
                                  width: 80,
                                  height: 80,
                                  // Remove explicit color tint to see if it shows natural colors first
                                  // but keep it subtle with opacity
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ),
        ),

        // Centered Brand Logo
        // Center(
        //   child: Column(
        //     mainAxisSize: MainAxisSize.min,
        //     children: [
        //       Container(
        //         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        //         decoration: BoxDecoration(
        //           color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        //           borderRadius: BorderRadius.circular(20),
        //         ),
        //         child: Opacity(
        //           opacity: isDark ? 0.8 : 1.0,
        //           child: Image.asset(
        //             'assets/FINISHD.png', // Trying this candidate for the full logo
        //             width: size.width * 0.4,
        //             fit: BoxFit.contain,
        //             color: isDark ? Colors.white : null,
        //           ),
        //         ),
        //       ),
        //       const SizedBox(height: 100), // Push logo up slightly from true center
        //     ],
        //   ),
        // ),

        // Foreground content (the screen's actual UI)
        Positioned.fill(child: widget.child),
      ],
    );
  }
}
