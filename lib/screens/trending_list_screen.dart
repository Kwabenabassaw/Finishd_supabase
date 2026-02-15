import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TrendingListScreen extends StatelessWidget {
  final String? date;

  const TrendingListScreen({super.key, this.date});

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
      body: FutureBuilder<Map<String, dynamic>?>(
        future: Supabase.instance.client
            .from('daily_trending')
            .select()
            .eq('date', queryDate)
            .maybeSingle(),
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

          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text(
                'No trending movies found for this date.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

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
