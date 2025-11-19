import 'package:finishd/LoadingWidget/playerloading.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Widget/Cast_avatar.dart';
import 'package:finishd/Widget/TvStreamingprovider.dart';
import 'package:finishd/Widget/TrailerPlayer.dart';
import 'package:finishd/onboarding/CategoriesTypeMove.dart';
import 'package:finishd/tmbd/fetch_trialler.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:redacted/redacted.dart';


// --- Placeholder/Mock Data Models ---
// Replace these with your actual TMDB models (Movie, CastMember, Season)
class TvShow {
  final int id;
  final TvShowDetails show;

  TvShow({required this.id, required this.show});
}

TvService tvService = TvService();
bool loadingService = false;


// --- The Main Widget ---
class ShowDetailsScreen extends StatefulWidget {
  final TvShowDetails movie;

  const ShowDetailsScreen({super.key, required this.movie});

  @override
  State<ShowDetailsScreen> createState() => _ShowDetailsScreenState();
}

class _ShowDetailsScreenState extends State<ShowDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          // 1. App Bar and Video Player Placeholder

          // 2. The Main Content Body
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Stack(
                      children: [
                        FutureBuilder(
                          future: tvService.getTVShowTrailerKey(
                            widget.movie.id.toString(),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return AnimatedTrailerCoverShimmer(
                               
                              );
                            }
                            if (snapshot.hasError) {
                              return _buildcover(
                                context,
                                widget.movie.posterPath.toString(),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data == null) {
                              return SizedBox(
                                height: 200,
                                child: Image.network(
                                  "https://image.tmdb.org/t/p/w500${widget.movie.posterPath}",
                                  fit: BoxFit.cover,
                                  height: 100,
                                  width: double.infinity,
                                ),
                              );
                            }
                            final trailerKey = snapshot.data!;
                            return AnimatedTrailerCover(
                              poster: widget.movie.posterPath.toString(),
                              youtubeKey: trailerKey,
                            );
                          },
                        ),
                      ],
                    ),

                    // Title and Runtime
                    _buildTitleAndRuntime(
                      widget.movie.name,
                      widget.movie.firstAirDate,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text("First Aired Date: "),
                        Text(widget.movie.firstAirDate),
                        SizedBox(width: 10),
                        Text("Last Aired Date: "),
                        Text(widget.movie.lastAirDate!),
                      ],
                    ),
    


     Streamingprovider(
  showId: widget.movie.id.toString(),title: widget.movie.name,

),



                    SizedBox(height: 5),
                    // Genres
                    Text(
                      widget.movie.genres.map((genre) => genre.name).join(", "),
                    ),
                    SizedBox(height: 5),
                    scoreWithLabel(widget.movie.voteAverage),

                 const SizedBox(height: 16),

                    // Streaming Services (Logos)
                    // _buildStreamingServices(),
                    // const SizedBox(height: 20),

                    // Description/Overview
                    Text(
                      widget.movie.overview,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 25),
                    const Text('Cast', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4,),
                      CastAvatar(showId:widget.movie.id,),
                    // const SizedBox(height: 25),

                    // Cast Section
                    // _buildCastSection(movie.cast),
                    // const SizedBox(height: 25),

                    // Recommended Section (Placeholder for complex logic)
                    _buildRecommendedSection(context),
                    const SizedBox(height: 25),

                    // Seasons/Episodes Section
                    _buildSeasonsSection(widget.movie.seasons),
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

  Widget _buildcover(BuildContext context, String poster) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => {},
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 50),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black87.withOpacity(0.5),
              BlendMode.srcATop,
            ),
            child: ClipRRect(
              borderRadius: BorderRadiusGeometry.circular(10),
              child: Image.network(
                "https://image.tmdb.org/t/p/w500${poster}",
                height: MediaQuery.of(context).size.height * 0.24,
                width: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 250.0, // Height of the video player area
      pinned: true,
      backgroundColor: Colors.white,

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
                      "https://image.tmdb.org/t/p/w500${widget.movie.posterPath}", // Placeholder image matching the visual
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
                    child: Row(children: [
                        

               
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

  Widget _buildTitleAndRuntime(String title, String runtime) {
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

  // Widget _buildGenres(<Genre> genres) {
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

  // Widget _buildCastSection(List<CastMember> cast) {
  Widget _buildRecommendedSection(context) {
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
          height: MediaQuery.of(context).size.height * 0.14,
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

  Widget _buildSeasonsSection(List<Season> seasons) {
    if (seasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${seasons.length} Seasons',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
                        imageUrl:
                            "https://image.tmdb.org/t/p/w500${season.posterPath}",
                        height: 180,
                        width: 140,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade300,
                          height: 180,
                          width: 140,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey,
                          height: 180,
                          width: 140,
                          child: const Icon(Icons.error, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      season.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
