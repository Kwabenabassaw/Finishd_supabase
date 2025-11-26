import 'package:finishd/LoadingWidget/playerloading.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Widget/Cast_avatar.dart';
import 'package:finishd/Widget/MovieStreamingprovider.dart';
import 'package:finishd/Widget/ScoreDisplay.dart';
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
           SliverAppBar(
          pinned: true,
          expandedHeight: 100,
          flexibleSpace: FlexibleSpaceBar(
          title: Text(  movie.title,style: TextStyle(color: Colors.black  ,fontSize: 20,fontWeight: FontWeight.bold)),
          centerTitle: true,
          ),
        ),
          // 2. The Main Content Body
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    // Title and Runtime
                    FutureBuilder(
                      future: tvService.getMovieTrailerKey(movie.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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

                        return AnimatedTrailerCover(
                          poster: movie.posterPath.toString(),
                          youtubeKey: snapshot.data!,
                        );
                      },
                    ),
                    _buildTitleAndRuntime(movie.title),
                    const SizedBox(height: 5),

                    // Genres
                    _buildGenres(
                      movie.genres.map((genre) => genre.name).toList(),
                    ),
                    //Streaming Service
                    Moviestreamingprovider(
                      showId: movie.id,
                      title: movie.title,
                    ),
                    const SizedBox(height: 5),
                    fancyAnimatedScoreWithLabel(
                      movie.voteAverage!,
                      label: "Rating",
                    ),
                    //Overview
                    Text(
                      movie.overview!,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 25),

                    // Cast Section
                    const Text(
                      'Cast',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
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
            ]),
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
          child: Icon(
            Icons.ios_share,
            color: Colors.black,
          ), // Using ios_share for similar look
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
                  imageUrl:
                      'https://i.imgur.com/5J3k80s.jpg', // Placeholder image matching the visual
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white),
                  ),
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
                        const Text(
                          'Killing Eve',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget fancyScoreWithLabel(double score, {required String label}) {
    // Convert score (assumed 0-10) to percentage (0-100)
    int percent = (score * 10).round();

    // Determine the color based on the percentage
    Color progressColor = percent >= 80
        ? Colors
              .green
              .shade600 // Excellent
        : percent >= 50
        ? Colors
              .amber
              .shade600 // Good
        : Colors.red.shade600; // Needs Improvement

    // Determine a subtle background/fill color for the row
    Color backgroundColor = progressColor.withOpacity(0.1);

    return Container(
      // Make the entire widget block slightly larger and give it a rounded background
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: backgroundColor, // Subtle colored background
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Keep the row content snug
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Score Circle and Text (Larger Stack)
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70, // Increased size
                height: 70, // Increased size
                child: CircularProgressIndicator(
                  value: score / 10, // Convert to 0–1
                  strokeWidth: 8, // Thicker stroke
                  backgroundColor: Colors.grey.shade200,
                  // Using a LinearProgressIndicator as a stand-in for rounded ends
                  // The actual CircularProgressIndicator doesn't easily support rounded ends directly.
                  // The surprise design element: We'll make the color transition nice.
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              // The score text inside the circle
              Text(
                "$percent%",
                style: TextStyle(
                  fontSize: 20, // Bolder score
                  fontWeight: FontWeight.w900,
                  color: progressColor, // Color matches the progress
                ),
              ),
            ],
          ),

          const SizedBox(width: 15), // Increased spacing
          // Label Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                _getScoreGrade(
                  percent,
                ), // Surprise Element: A descriptive grade
                style: TextStyle(
                  fontSize: 14,
                  color: progressColor, // Color matches the score/progress
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper function to provide a descriptive grade
  String _getScoreGrade(int percent) {
    if (percent >= 90) return "Excellent";
    if (percent >= 70) return "Very Good";
    if (percent >= 50) return "Good";
    if (percent >= 30) return "Fair";
    return "Poor";
  }

  // Example usage:
  // fancyScoreWithLabel(8.5, label: "Customer Satisfaction")
  //

  Widget _buildTitleAndRuntime(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGenres(List<String> genres) {
    return Row(
      children: [
        ...genres
            .map(
              (genre) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  genre,
                  style: const TextStyle(color: Colors.black54, fontSize: 16),
                ),
              ),
            )
            .toList(),
        // Runtime
        const Text('•', style: TextStyle(color: Colors.black54, fontSize: 16)),
        Text(
          movie.runtime.toString(),
          style: const TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const Text(
          'min',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildStreamingServices(List<String> services) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: services
          .map(
            (service) => Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              // Placeholder for service logos
              child: Text(
                service.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
          )
          .toList(),
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
            const Text(
              'Recommended by',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.black),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 15),
        // Mock people profiles
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildPersonTile(
                'Esther Howard',
                'https://i.imgur.com/qE4J3gI.jpg',
              ),
              _buildPersonTile(
                'Brooklyn Simmons',
                'https://i.imgur.com/7w3k9Xm.jpg',
              ),
              _buildPersonTile(
                'Cameron Williamson',
                'https://i.imgur.com/hXG2Z0S.jpg',
              ),
              _buildPersonTile(
                'Kwabena Mensah',
                'https://i.imgur.com/R5v8q2y.jpg',
              ),
            ],
          ),
        ),
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

  Widget _buildSeasonsSection(BuildContext context, List<Season> seasons) {
    if (seasons.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.35 > 140 ? 140.0 : screenWidth * 0.35;
    final cardHeight = cardWidth * 1.3; // Approx aspect ratio

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${seasons.length} Seasons',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: cardHeight + 40, // Height for the season posters + text
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];
              return Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: season.posterPath.toString(),
                          height: cardHeight,
                          width: cardWidth,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade300,
                            height: cardHeight,
                            width: cardWidth,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey,
                            height: cardHeight,
                            width: cardWidth,
                            child: const Icon(Icons.error, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        season.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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

