
import 'package:flutter/material.dart';

class SearchScreenHome extends StatefulWidget {
  const SearchScreenHome({super.key});

  @override
  State<SearchScreenHome> createState() => _SearchScreenHomeState();
}

class _SearchScreenHomeState extends State<SearchScreenHome> {
  final List<Map<String, String>> _suggestions = [
    {
      'title': 'The Batman',
      'subtitle': 'related to your recent search',
    },
    {
      'title': 'Oppenheimer',
      'subtitle': 'related to your recent search',
    },
    {
      'title': 'Elemental',
      'subtitle': 'trending',
    },
    {
      'title': 'Barbie',
      'subtitle': '',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background as per image
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header with Back Button & Search Field
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        autofocus: true, // Pops up keyboard
                        textAlignVertical: TextAlignVertical.center,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          hintText: "Search for people, favourite or trending movies.",
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. "You may like" Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "You may like",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: const [
                        Icon(Icons.refresh, size: 14, color: Colors.black54),
                        SizedBox(width: 4),
                        Text(
                          "Refresh",
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. List of Suggestions
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final item = _suggestions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Green Dot
                        Container(
                          margin: const EdgeInsets.only(top: 8, right: 15),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green, // Distinctive green dot
                            shape: BoxShape.circle,
                          ),
                        ),
                        // Text Content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: const TextStyle(
                                color: Colors.black, // Changed to dark green/black based on image
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item['subtitle']!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item['subtitle']!,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ]
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}