import 'package:finishd/Model/shows.dart';
import 'package:finishd/MovieDetails/movie_details_screen.dart';
import 'package:finishd/services/getShow.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MovieHorizontalList extends StatefulWidget {
  const MovieHorizontalList({super.key});

  @override
  State<MovieHorizontalList> createState() => _MovieHorizontalListState();
}

class _MovieHorizontalListState extends State<MovieHorizontalList> {
  List<Welcome>? shows; // store data here
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getData();
  }

  Future<void> getData() async {
    try {
      final data = await Getshow().getshows();
      setState(() {
        shows = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading shows: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (shows == null || shows!.isEmpty) {
      return const Center(child: Text("No shows found"));
    }

    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: shows!.length,
        itemBuilder: (context, index) {
          final movie = shows![index];
          
          return MovieCard(movie: movie);

        },
      ),
    );
  }
}

class MovieCard extends StatelessWidget {
  const MovieCard({
    super.key,
    required this.movie,
  });

  final Welcome movie;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        Navigator.push(context, 
        MaterialPageRoute(builder: (context)=> MovieDetailsScreen(movie:movie))
        );
      },
    child: 
    Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              
            child: CachedNetworkImage(imageUrl: movie.image?.medium ?? '',)
            ),
            const SizedBox(height: 6),
            Text(
              movie.name ?? "No title",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              movie.type ?? "Genre unknown",
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    )
    );
  }
}
