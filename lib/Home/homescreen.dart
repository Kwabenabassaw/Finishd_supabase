import 'package:flutter/material.dart';


import 'shareSceen.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLiked = false;
  double sliderValue = 0;
  final List<Map<String, String>> _feedItems = [
    {
      'image':
          'https://images.unsplash.com/photo-1535295972055-1c762f4483e5?q=80&w=2574&auto=format&fit=crop',
      'title': 'Superman',
      'description':
          'Clark learns about the source of his abilities and his real home when he enters a Kryptonian ship in the Arctic.',
      'likes': '1.2M',
      'comments': '4,021',
    },
    {
      'image':
          'https://images.unsplash.com/photo-1536440136628-849c177e76a1?q=80&w=2525&auto=format&fit=crop',
      'title': 'Rainmaker',
      'description':
          'Season 1 Finale: The courtroom drama intensifies as the team faces their biggest challenge yet.',
      'likes': '850K',
      'comments': '2,100',
    },
    {
      'image':
          'https://images.unsplash.com/photo-1541963463532-d68292c34b19?q=80&w=2576&auto=format&fit=crop',
      'title': 'Dune: Prophecy',
      'description':
          '10,000 years before the ascension of Paul Atreides, the Bene Gesserit is founded.',
      'likes': '2.4M',
      'comments': '15K',
    },
  ];

  // Emoji slider data
  final List<String> _emojis = ["😍", "😎", "😢", "😊", "🤩", "🤯", "😂"];

  // Function to show the emoji slider
  void _showEmojiSlider() {
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
                height: MediaQuery.of(context).size.height * 0.5,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    // Emoji display on the left
                    Text(
                      _emojis[sliderValue.toInt()],
                      style: const TextStyle(fontSize: 40),
                    ),

                    // Vertical Slider on the right
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Slider(
                          value: sliderValue,
                          min: 0,
                          max: (_emojis.length - 1).toDouble(),
                          divisions: _emojis.length - 1,
                          label: _emojis[sliderValue.toInt()],
                          onChanged: (value) {
                            setState(() {
                              sliderValue = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _feedItems.length,
      itemBuilder: (context, index) {
        final item = _feedItems[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            Image.network(
              item['image']!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(color: Colors.grey[900]);
              },
            ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.15, 0.6, 1.0],
                ),
              ),
            ),

            // Top bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, 'notification'),
                    child: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        "Friends",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          const Text(
                            "Explore",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 5),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(width: 30, height: 2, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, 'homesearch'),

                    child: const Icon(
                      Icons.search,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Right sidebar
            Positioned(
              right: 10,
              bottom: 80 + MediaQuery.of(context).padding.bottom,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => {
                      Navigator.pushNamed(context, 'comment'),
                    },
                    child: _buildActionBtn(
                      Icons.chat_bubble_outline_outlined,
                      "Comments",
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => {
                      Navigator.pushNamed(context, 'friends'),
                    },
                    child: _buildActionBtn(Icons.people_outline_outlined, "Friends"),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onLongPress: () {
                      _showEmojiSlider();
                      setState(() {
                        isLiked = true;
                      });
                    }, // LONG PRESS shows slider
                    onDoubleTap: () {
                      setState(() {
                        isLiked = false;
                      });
                    },
                    child: _buildActionBtn(
                      isLiked ? Icons.favorite : Icons.favorite_border_outlined,
                      "Like",
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => {
                      showShareBottomSheet(context),
                    },
                    child: _buildActionBtn(Icons.share_outlined, "Share"),
                  )
                ],
              ),
            ),

            // Bottom info
            Positioned(
              left: 20,
              right: 80,
              bottom: 40 + MediaQuery.of(context).padding.bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['description']!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.3,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 2)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionBtn(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }
}

