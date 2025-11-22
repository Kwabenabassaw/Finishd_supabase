import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Discover/discover.dart';
import 'package:finishd/Model/trending.dart';
import 'package:finishd/Widget/serviceLogoTileSkeleton.dart';
import 'package:finishd/tmbd/Search.dart';
import 'package:finishd/tmbd/fetchDiscover.dart';
import 'package:finishd/tmbd/fetchtrending.dart';
import 'package:flutter/material.dart';

// Define the primary green color
const Color primaryGreen = Color(0xFF1E88E5); 
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
  final Set<String> _selectedShowTitles = {};
  final TextEditingController _searchController = TextEditingController();
String _searchQuery = '';
 final Future<List<MediaItem>> sampleShows = getDiscover.fetchDiscover() ;
Future<List<MediaItem>> get search => movieapi.getSearch(_searchQuery);

  
  void _toggleShowSelection(String title) {
    setState(() {
      if (_selectedShowTitles.contains(title)) {
        _selectedShowTitles.remove(title);
      } else {
        _selectedShowTitles.add(title);
      }
    });
  }
  
      Future<List<MediaItem>>? _futureShows;

      @override
void initState() {
  super.initState();
  _futureShows = getDiscover.fetchDiscover(); // Load discover only ONCE
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  const Text(
                    'Shows you\'ve loved',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
               
                  const Text(
                    'Select shows you\'ve enjoyed. We\'ll find similar ones you haven\'t seen yet.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
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
                      if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                        return const PosterShimmerGrid();
                      } else if (asyncSnapshot.hasError) {
                        return Text('Error: ${asyncSnapshot.error}');
                      }
                  

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                          childAspectRatio: 0.65, // Adjust for poster size (taller than wide)
                        ),
                        itemCount: show!.length,
                        itemBuilder: (context, index) {
                          final shows = show[index];
                          final isSelected = _selectedShowTitles.contains(shows.title);
                      
                          return ShowPosterTile(
                            show: shows,
                            isSelected: isSelected,
                            onTap: () => _toggleShowSelection(shows.title),
                          );
                        },
                      );
                    }
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
                valueColor: const AlwaysStoppedAnimation<Color>(Color((0xFF1A8927))),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 15),
            const Text(
              '50%',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Step 2 of 4',
          style: TextStyle(
     
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Helper widget for the search bar
  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
      
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            if(_searchQuery.isEmpty){
              _futureShows = getDiscover.fetchDiscover();
            }else{
              _futureShows = movieapi.getSearch(_searchQuery);
            }
          });
        },
        style: const TextStyle(color: Colors.black  ),
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
    return Container(
      color: Colors.white, // Background color for the bottom bar
      padding: EdgeInsets.only(
        left: 25.0,
        right: 25.0,
        top: 15.0,
        bottom: MediaQuery.of(context).padding.bottom + 15, // Account for safe area
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _selectedShowTitles.isNotEmpty ? () {
                print('Selected Shows: $_selectedShowTitles');
                
                Navigator.pushReplacementNamed(context, 'streaming');
              } : null, // Disable if no shows are selected
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
          // Skip Button
          TextButton(
            onPressed: () {
              print('Skipped this step');
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
              imageUrl: "https://image.tmdb.org/t/p/w500${show.posterPath}" ,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (context, url, error) => Image.asset("assets/noimage.jpg"),
           
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
                backgroundColor:  Color((0xFF1A8927)),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
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