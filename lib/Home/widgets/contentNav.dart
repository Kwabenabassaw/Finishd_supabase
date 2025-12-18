import 'package:flutter/material.dart';

class ContentNav extends StatefulWidget {
  const ContentNav({Key? key}) : super(key: key);

  @override
  _ContentNavState createState() => _ContentNavState();
}

class _ContentNavState extends State<ContentNav> {
  final List<String> contentNav = ["Trending", "Following", "For You"];
  int? selectedIndex = 0; // Default to first item like TikTok

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Center items like TikTok
      children: List.generate(contentNav.length, (index) {
        bool isActive = selectedIndex == index;

        return GestureDetector(
          onTap: () {
            setState(() {
              // Deselect logic: if already selected, set to null
              selectedIndex = (selectedIndex == index) ? null : index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Wrap content tightly
              children: [
                Text(
                  contentNav[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white60,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4), // Gap between text and line
                // The TikTok-style indicator
                Container(
                  height: 2,
                  width: 25, // Fixed small width regardless of text size
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}