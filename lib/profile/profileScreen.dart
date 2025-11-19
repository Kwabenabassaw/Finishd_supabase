import 'package:finishd/profile/MoviePosterGrid.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Mock Data Models (Replace with your actual data models) ---
class UserProfile {
  final String name;
  final String email;
  final String avatarUrl;
  final String bio;
  final int finishdCount;
  final int followersCount;
  final int followingCount;

  UserProfile({
    required this.name,
    required this.email,
    this.avatarUrl = 'https://i.imgur.com/gYV4f8P.png', // Default avatar
    this.bio = 'Bio text here 😉',
    this.finishdCount = 43,
    this.followersCount = 35,
    this.followingCount = 16,
  });
}

// Simplified Movie class for the grid (using Result from TMDB for example)
class MovieItem {
  final int id;
  final String? title;
  final String? posterPath;
  final String? genre; // Simplified for display
  
  MovieItem({
    required this.id,
    this.title,
    this.posterPath,
    this.genre,
  });

  // Example fromJson if you're using TMDB Result
  factory MovieItem.fromTmdbResult(Map<String, dynamic> json) {
    return MovieItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? json['name'] as String?, // handle movie/tv title
      posterPath: json['poster_path'] as String?,
      genre: 'Genre Genre Genre', // Placeholder for actual genre logic
    );
  }
}

// Utility for TMDB image URLs
String getTmdbImageUrl(String? path, {String size = 'w500'}) {
  if (path == null || path.isEmpty) {
    return 'https://via.placeholder.com/200x300?text=No+Image';
  }
  return 'https://image.tmdb.org/t/p/$size$path';
}

// --- Main Profile Screen Widget ---
class ProfileScreen extends StatefulWidget {
  final UserProfile userProfile;

  const ProfileScreen({super.key, required this.userProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock data for the tabs
  final List<MovieItem> _finishdMovies = [
    MovieItem(id: 1, title: 'Ne Zha : 2', posterPath: '/r9P4W2H0C25QhSjK369zD12P2F.jpg'),
    MovieItem(id: 2, title: 'Killing Eve', posterPath: '/vQirS1w7fXWf33E7c6J7u3wJ6M.jpg'),
    MovieItem(id: 3, title: 'The Ice Road', posterPath: '/mQhRTMd46Kj0m1D2pI0S0l4M1K.jpg'),
    MovieItem(id: 4, title: 'Until Dawn', posterPath: '/yF1eOkaYveaRiP1KwsgehFVADC5.jpg'),
    MovieItem(id: 5, title: 'Tony & Ziva', posterPath: '/tUeYd6bWvJzG6sJ4p5p8J7p5r8S.jpg'),
    MovieItem(id: 6, title: 'Fractured', posterPath: '/qAykD5rX5L8S6Y3xJ8v7U2q6Y4S.jpg'),
    MovieItem(id: 7, title: 'Mock Movie 7', posterPath: '/r9P4W2H0C25QhSjK369zD12P2F.jpg'),
    MovieItem(id: 8, title: 'Mock Movie 8', posterPath: '/vQirS1w7fXWf33E7c6J7u3wJ6M.jpg'),
  ];

  final List<MovieItem> _watchingMovies = [
    MovieItem(id: 10, title: 'Currently Watching', posterPath: '/mQhRTMd46Kj0m1D2pI0S0l4M1K.jpg'),
    MovieItem(id: 11, title: 'Another Show', posterPath: '/yF1eOkaYveaRiP1KwsgehFVADC5.jpg'),
  ];
  final List<MovieItem> _watchLaterMovies = [
     MovieItem(id: 20, title: 'Later List', posterPath: '/tUeYd6bWvJzG6sJ4p5p8J7p5r8S.jpg'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
      
        title: const Text('Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
             Navigator.pushNamed(context, 'settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // User Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: CachedNetworkImageProvider(widget.userProfile.avatarUrl),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            // User Name
            Text(
              widget.userProfile.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            // User Email
            Text(
              widget.userProfile.email,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn("FinishD", widget.userProfile.finishdCount),
                _buildStatColumn("Followers", widget.userProfile.followersCount),
                _buildStatColumn("Following", widget.userProfile.followingCount),
              ],
            ),
            const SizedBox(height: 20),

            // Edit Profile Button
            ElevatedButton.icon(
              onPressed: () {
                // Handle edit profile tap
              },
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 3, 130, 7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              ),
            ),
            const SizedBox(height: 15),

            // Bio Text
            Text(
              widget.userProfile.bio,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),

            // Tabs for content
            _buildTabBar(),
            SizedBox(
              // Adjust height based on content to avoid overflow or empty space
              height: MediaQuery.of(context).size.height - 350, // Example adjustment
              child: TabBarView(
                controller: _tabController,
                children: [
                  MoviePosterGrid(movies: _finishdMovies),
                  MoviePosterGrid(movies: _watchingMovies),
                  MoviePosterGrid(movies: _watchLaterMovies),
                ],
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation Bar
     
    );
  }

  // --- Helper Widgets for ProfileScreen ---

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize:14, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.black, // Active tab indicator color
        labelColor: Colors.black, // Active tab text color
        unselectedLabelColor: Colors.grey, // Inactive tab text color
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        tabs: const [
          Tab(text: 'FinishD'),
          Tab(text: 'Watching'),
          Tab(text: 'Watch Later'),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed, // Ensures all items are visible
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '', // Empty label to mimic the image
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_border),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '',
        ),
      ],
      onTap: (index) {
        // Handle navigation to different sections of the app
        print('Bottom nav item $index tapped');
      },
    );
  }
}