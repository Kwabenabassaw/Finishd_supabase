import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Discover/discover.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/Widget/serviceLogoTileSkeleton.dart';
import 'package:finishd/provider/onboarding_provider.dart';
import 'package:finishd/tmbd/Search.dart';
import 'package:finishd/tmbd/fetchDiscover.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Define the primary green color
const Color primaryGreen = Color(0xFF1A8927);
Fetchdiscover getDiscover = Fetchdiscover();
SearchDiscover movieapi = SearchDiscover();

// Data model for a TV show
class Show {
  final String title;
  final String imageUrl;
  Show(this.title, this.imageUrl);
}

// Example list of shows (Replace with your actual asset or network paths)

class ShowSelectionScreen extends StatefulWidget {
  const ShowSelectionScreen({super.key});

  @override
  State<ShowSelectionScreen> createState() => _ShowSelectionScreenState();
}

class _ShowSelectionScreenState extends State<ShowSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Future<List<MediaItem>> sampleShows = getDiscover.fetchDiscover();
  Future<List<MediaItem>> get search => movieapi.getSearch(_searchQuery);

  Future<List<MediaItem>>? _futureShows;

  @override
  void initState() {
    super.initState();
    _futureShows = getDiscover.fetchDiscover(); // Load discover only ONCE
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // Use Stack to place the bottom buttons persistently over the scrollable content
      body: Stack(
        children: [
          // --- Main Scrollable Content Area ---
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 20.0,
                left: 25.0,
                right: 25.0,
                bottom: 180.0, // Important: Space for the fixed bottom bar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Progress Bar and Step (Step 2 of 4, 50%)
                  const SizedBox(height: 30),
                  _buildProgressHeader(),
                  const SizedBox(height: 40),

                  // 2. Title and Subtitle
                  Text(
                    'Shows you\'ve loved',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),

                  const Text(
                    'Select shows you\'ve enjoyed. We\'ll find similar ones you haven\'t seen yet.',
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // 3. Search Bar
                  _buildSearchBar(),
                  const SizedBox(height: 25),

                  // 4. Show Poster Grid
                  FutureBuilder(
                    future: _futureShows,
                    builder: (context, asyncSnapshot) {
                      final show = asyncSnapshot.data;
                      if (asyncSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const PosterShimmerGrid();
                      } else if (asyncSnapshot.hasError) {
                        return Text('Error: ${asyncSnapshot.error}');
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10.0,
                              mainAxisSpacing: 10.0,
                              childAspectRatio:
                                  0.65, // Adjust for poster size (taller than wide)
                            ),
                        itemCount: show!.length,
                        itemBuilder: (context, index) {
                          final shows = show![index];
                          final onboardingProvider =
                              Provider.of<OnboardingProvider>(
                                context,
                                listen: true,
                              );
                          final isSelected = onboardingProvider.isMediaSelected(
                            shows.id,
                            shows.mediaType,
                          );
                          return ShowPosterTile(
                            show: shows,
                            isSelected: isSelected,
                            onTap: () {
                              final media = SelectedMedia(
                                id: shows.id,
                                title: shows.title,
                                posterPath: shows.posterPath,
                                mediaType: shows.mediaType,
                              );
                              onboardingProvider.toggleMedia(media);
                            },
                          );
                        },
                      );
                    },
                  ),
                  // Add extra padding at the bottom of the grid if necessary
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // --- Fixed Bottom Button Bar ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomButtonBar(),
          ),
        ],
      ),
    );
  }

  // Helper widget for the top progress header
  Widget _buildProgressHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: 0.50, // 50% progress for Step 2 of 4
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color((0xFF1A8927)),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 15),
            const Text(
              '50%',
              style: TextStyle(
             
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Step 2 of 4',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // Helper widget for the search bar
  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            if (_searchQuery.isEmpty) {
              _futureShows = getDiscover.fetchDiscover();
            } else {
              _futureShows = movieapi.getSearch(_searchQuery);
            }
          });
        },
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: const InputDecoration(
          hintText: 'Search for shows...',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none, // Removes the default border
          contentPadding: EdgeInsets.only(top: 15),
        ),
      ),
    );
  }

  // Helper widget for the bottom buttons
  Widget _buildBottomButtonBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.white,
      padding: EdgeInsets.only(
        left: 25.0,
        right: 25.0,
        top: 15.0,
        bottom:
            MediaQuery.of(context).padding.bottom + 15, // Account for safe area
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                final onboardingProvider = Provider.of<OnboardingProvider>(
                  context,
                  listen: false,
                );
                final hasSelections =
                    onboardingProvider.selectedMovies.isNotEmpty ||
                    onboardingProvider.selectedShows.isNotEmpty;

                if (hasSelections) {
                  print(
                    'Selected Movies: ${onboardingProvider.selectedMovies}',
                  );
                  print('Selected Shows: ${onboardingProvider.selectedShows}');
                  Navigator.pushNamed(context, 'streaming');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color((0xFF1A8927)),
                disabledBackgroundColor: Color((0xFF1A8927)).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              print('Skipped this step');
              Navigator.pushNamed(context, 'streaming');
            },
            child: const Text(
              'Skip this step',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helper Widget: The Individual Show Poster Tile ---
class ShowPosterTile extends StatelessWidget {
  final MediaItem show;
  final bool isSelected;
  final VoidCallback onTap;

  const ShowPosterTile({
    super.key,
    required this.show,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Poster Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: CachedNetworkImage(
              imageUrl: "https://image.tmdb.org/t/p/w500${show.posterPath}",
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (context, url, error) =>
                  Image.asset("assets/noimage.jpg"),
            ),
          ),

          // Selection Overlay (A gradient and checkmark)
          if (isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  // Semi-transparent overlay to highlight selection
                  color: Colors.white.withOpacity(0.5),
                  border: Border.all(color: Color((0xFF1A8927)), width: 3),
                ),
              ),
            ),

          // Checkmark Icon
          if (isSelected)
            const Positioned(
              top: 5,
              right: 5,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Color((0xFF1A8927)),
                child: Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// void main() {
//   runApp(const MaterialApp(home: ShowSelectionScreen()));
// }
