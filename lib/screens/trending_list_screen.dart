import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finishd/models/feed_video.dart'; // Reusing FeedVideo or create a Movie model if available
// Assuming you have a MovieDetails or similar screen to navigate to
// import 'package:finishd/MovieDetails/MovieDetailsScreen.dart';

class TrendingListScreen extends StatelessWidget {
  final String? date;

  const TrendingListScreen({Key? key, this.date}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use today's date if none provided
    final queryDate = date ?? DateTime.now().toIso8601String().split('T')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Trending'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('notifications')
            .doc('daily_trending')
            .collection('dates')
            .doc(queryDate)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'No trending movies found for this date.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List<dynamic> movies = data['movies'] ?? [];

          return ListView.builder(
            itemCount: movies.length,
            itemBuilder: (context, index) {
              final movie = movies[index];
              final posterPath = movie['poster_path'];
              final imageUrl = posterPath != null
                  ? 'https://image.tmdb.org/t/p/w500$posterPath'
                  : 'https://via.placeholder.com/150';

              return ListTile(
                leading: Image.network(imageUrl, width: 50, fit: BoxFit.cover),
                title: Text(
                  movie['title'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  movie['overview'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  // Navigate to details
                  // Navigator.pushNamed(context, '/movie_details', arguments: movie['id']);
                },
              );
            },
          );
        },
      ),
    );
  }
}
