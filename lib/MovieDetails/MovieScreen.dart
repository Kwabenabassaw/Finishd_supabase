import 'package:finishd/LoadingWidget/playerloading.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Widget/Cast_avatar.dart';
import 'package:finishd/Widget/MovieStreamingprovider.dart';
import 'package:finishd/Widget/TrailerPlayer.dart';
import 'package:finishd/Widget/TvStreamingprovider.dart';
import 'package:finishd/tmbd/fetch_trialler.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Placeholder/Mock Data Models ---
// Replace these with your actual TMDB models (Movie, CastMember, Season)


TvService tvService = TvService();

// --- The Main Widget ---
class MovieDetailsScreen extends StatelessWidget {
  final MovieDetails movie;

  const MovieDetailsScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          
            
          // 2. The Main Content Body
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 10),
                      // Title and Runtime
                      FutureBuilder(future: tvService.getMovieTrailerKey(movie.id), 
                      builder:(context, snapshot) {

                        if (snapshot.connectionState ==ConnectionState.waiting){
                              return AnimatedTrailerCoverShimmer();
                            }
                               if (snapshot.hasError) {
                                return const Text("Couldn't load trailer");
                            }
                                if (!snapshot.hasData || snapshot.data == null) {
                              return SizedBox(
                                height: 200,
                                child: Image.network(
                                  "https://image.tmdb.org/t/p/w500${movie.posterPath}",
                                  fit: BoxFit.cover,
                                  height: 100,
                                  width: double.infinity,
                                ),
                              );
                            }

                            return AnimatedTrailerCover(poster: movie.posterPath.toString(), youtubeKey: snapshot.data!);
   } ),
                      _buildTitleAndRuntime(movie.title),
                      const SizedBox(height: 5),
                    
                      // Genres
                      _buildGenres(movie.genres.map((genre)=>genre.name).toList()),
                      //Streaming Service
                      Moviestreamingprovider(showId: movie.id,title: movie.title,),
                      const SizedBox(height: 5),
                      scoreWithLabel(movie.voteAverage!),
                      //Overview
                      Text(
                        movie.overview!,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 25),

                      // Cast Section
                      const Text('Cast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4,),
                      MovieCastAvatar(movieId: movie.id),

                      // _buildCastSection(movie.cast),
                      // const SizedBox(height: 25),

                      // Recommended Section (Placeholder for complex logic)
                      _buildRecommendedSection(),
                      const SizedBox(height: 25),

                      // // Seasons/Episodes Section
                      // _buildSeasonsSection(movie.seasons),
                      // const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // -------------------------------------------------------------------
  // Helper Widget Builders (Defined outside the build method for clarity)
  // -------------------------------------------------------------------

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 250.0, // Height of the video player area
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: const [
        // Heart Icon (Favorite)
        Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: Icon(Icons.favorite_border, color: Colors.black),
        ),
        // Share Icon
        Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: Icon(Icons.share, color: Colors.black),
        ),
        // Options Icon
        Padding(
          padding: EdgeInsets.only(right: 16.0),
          child: Icon(Icons.ios_share, color: Colors.black), // Using ios_share for similar look
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        background: AspectRatio(
          aspectRatio: 16 / 9,
          // Video Player Placeholder Area
          child: Container(
            color: Colors.black, // Background of the player
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Replace with your actual video player widget (e.g., video_player, youtube_player_flutter)
                CachedNetworkImage(
                  imageUrl: 'https://i.imgur.com/5J3k80s.jpg', // Placeholder image matching the visual
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
                ),
                // Play Button
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 50,
                ),
                // Custom progress bar/timeline (Mocked with a simple row)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Text('Killing Eve', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const Icon(Icons.graphic_eq, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text('2M', style: TextStyle(color: Colors.white)),
                        const Spacer(),
                        // Mock timeline
                        Container(height: 2, width: 80, color: Colors.red),
                        Container(height: 2, width: 40, color: Colors.grey),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
 Widget scoreWithLabel(double score) {
    int percent = (score * 10).round();

    return Row(
      children: [
        // Score Circle
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: score / 10, // Convert to 0–1
                strokeWidth: 5,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percent >= 70
                      ? Colors.green
                      : percent >= 40
                      ? Colors.yellow
                      : Colors.red,
                ),
              ),
            ),
            Text(
              "$percent%",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(width: 10),

        Column(children: [Text("User"), Text("Score")]),

        // Label
      ],
    );
  }
  Widget _buildTitleAndRuntime(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
      
      ],
    );
  }

  Widget _buildGenres(List<String> genres) {
    return Row(
      children: [
        ...genres.map((genre) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Text(genre, style: const TextStyle(color: Colors.black54, fontSize: 16)),
        )).toList(),
        // Runtime
        const Text('•', style: TextStyle(color: Colors.black54, fontSize: 16)),
        Text(movie.runtime.toString(), style: const TextStyle(color: Colors.black54, fontSize: 16)),
        const Text('min', style: TextStyle(color: Colors.black54, fontSize: 16)),
      ],
    );
  }

  Widget _buildStreamingServices(List<String> services) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: services.map((service) => Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        // Placeholder for service logos
        child: Text(
          service.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      )).toList(),
    );
  }

  // Widget _buildCastSection(List<Cast> cast) {
  //   if (cast.isEmpty) return const SizedBox.shrink();

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text('Cast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
  //       const SizedBox(height: 15),
  //       SizedBox(
  //         height: 100, // Height for the horizontal list
  //         child: ListView.builder(
  //           scrollDirection: Axis.horizontal,
  //           itemCount: cast.length,
  //           itemBuilder: (context, index) {
  //             final member = cast[index];
  //             return Padding(
  //               padding: const EdgeInsets.only(right: 20.0),
  //               child: Column(
  //                 children: [
  //                   CircleAvatar(
  //                     radius: 30,
  //                     backgroundImage: CachedNetworkImageProvider(member.imageUrl),
  //                     backgroundColor: Colors.grey.shade200,
  //                   ),
  //                   const SizedBox(height: 8),
  //                   SizedBox(
  //                     width: 60,
  //                     child: Text(
  //                       member.name,
  //                       textAlign: TextAlign.center,
  //                       maxLines: 2,
  //                       overflow: TextOverflow.ellipsis,
  //                       style: const TextStyle(fontSize: 12),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             );
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildRecommendedSection() {
    // This is often a placeholder since recommendations are complex to mock
    // It maintains the structure from the image.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recommended by', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.arrow_forward, color: Colors.black), onPressed: () {}),
          ],
        ),
        const SizedBox(height: 15),
        // Mock people profiles
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildPersonTile('Esther Howard', 'https://i.imgur.com/qE4J3gI.jpg'),
              _buildPersonTile('Brooklyn Simmons', 'https://i.imgur.com/7w3k9Xm.jpg'),
              _buildPersonTile('Cameron Williamson', 'https://i.imgur.com/hXG2Z0S.jpg'),
              _buildPersonTile('Kwabena Mensah', 'https://i.imgur.com/R5v8q2y.jpg'),
            ],
          ),
        )
      ],
    );
  }
  
  Widget _buildPersonTile(String name, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(right: 20.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: CachedNetworkImageProvider(imageUrl),
            backgroundColor: Colors.yellow, // Mock color
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonsSection(List<Season> seasons) {
    if (seasons.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${seasons.length} Seasons', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        SizedBox(
          height: 220, // Height for the season posters
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];
              return Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: season.posterPath.toString(),
                        height: 180,
                        width: 140,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey.shade300, height: 180, width: 140),
                        errorWidget: (context, url, error) => Container(color: Colors.grey, height: 180, width: 140, child: const Icon(Icons.error, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(season.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


// -------------------------------------------------------------------
// Example Usage (for testing the screen)
// -------------------------------------------------------------------

