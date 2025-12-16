import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/onboarding_provider.dart';

// Define the primary green color
const Color primaryGreen = Color(0xFF1A8927);

// Data model for genres
class Genre {
  final String name;
  final String emoji;
  final int genreId; // TMDB genre ID
  Genre(this.name, this.emoji, this.genreId);
}

// Example genre list with TMDB genre IDs
final List<Genre> genres = [
  Genre('Drama', '🎭', 18),
  Genre('Comedy', '😂', 35),
  Genre('Romance', '💖', 10749),
  Genre('Action', '🔫', 28),
  Genre('Horror', '👻', 27),
  Genre('Sci-Fi', '🚀', 878),
  Genre('Documentary', '🎥', 99),
  Genre('Thriller', '🔪', 53),
];

class GenreSelectionScreen extends StatefulWidget {
  const GenreSelectionScreen({super.key});

  @override
  State<GenreSelectionScreen> createState() => _GenreSelectionScreenState();
}

class _GenreSelectionScreenState extends State<GenreSelectionScreen> {
  final int _minSelections = 3;

  @override
  Widget build(BuildContext context) {
    final onboardingProvider = Provider.of<OnboardingProvider>(context);
    final bool isContinueEnabled =
        onboardingProvider.selectedGenres.length >= _minSelections;

    return Scaffold(
      // Wrap the content in a Column to place it above the bottom button
      body: SafeArea(
        child: Column(
          children: [
            // --- Top Content Area ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Progress Bar and Step
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: 0.25, // 25% progress for Step 1 of 4
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
                          '25%',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Step 1 of 4',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 2. Title
                    const Text(
                      'What do you love to watch?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. Subtitle / Instructions
                    Text(
                      'Pick at least $_minSelections genres you enjoy. This helps us find shows you\'ll actually finish.',
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),

                    // 4. Genre Selection Grid
                    // Using GridView.builder for a consistent 2-column layout
                    GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // Important to scroll with parent
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15.0,
                        mainAxisSpacing: 15.0,
                        childAspectRatio:
                            1.25, // Adjust this ratio for height/width of the tiles
                      ),
                      itemCount: genres.length,
                      itemBuilder: (context, index) {
                        final genre = genres[index];
                        final isSelected = onboardingProvider.isGenreSelected(
                          genre.name,
                        );

                        return GenreChip(
                          genre: genre,
                          isSelected: isSelected,
                          onTap: () => onboardingProvider.toggleGenre(
                            genre.name,
                            genre.genreId,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: EdgeInsets.only(
                left: 25.0,
                right: 25.0,
                top: 15.0,
                bottom: MediaQuery.of(context).padding.bottom + 25.0,
              ),
              // Optional: Add a subtle shadow/border to separate the button area
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1.0),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isContinueEnabled
                      ? () {
                          // Add haptic feedback
                          HapticFeedback.mediumImpact();
                          // Action when Continue is pressed
                          print(
                            'Selected Genres: ${onboardingProvider.selectedGenres}',
                          );
                          print(
                            'Selected Genre IDs: ${onboardingProvider.selectedGenreIds}',
                          );
                          // Use pushNamed for back navigation support
                          Navigator.pushNamed(context, 'showSelect');
                        }
                      : null, // Button is disabled if not enough genres are selected
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color((0xFF1A8927)),
                    disabledBackgroundColor: Color(
                      (0xFF1A8927),
                    ).withOpacity(0.5), // Lighter green when disabled
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
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widget: The Genre Selection Tile ---
class GenreChip extends StatelessWidget {
  final Genre genre;
  final bool isSelected;
  final VoidCallback onTap;

  const GenreChip({
    super.key,
    required this.genre,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade800.withOpacity(0.1)
              : Colors.white, // Light green fill when selected
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.green.shade800 : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji (displayed as large text)
            Center(
              child: Text(
                genre.emoji,
                style: const TextStyle(fontSize: 36),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            // Genre Name
            Center(
              child: Text(
                genre.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.green.shade800 : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// void main() {
//   runApp(const MaterialApp(home: GenreSelectionScreen()));
// }
