    import 'package:flutter/material.dart';

// Define the primary green color
const Color primaryGreen = Color((0xFF1A8927)); 

// Data model for a streaming service
class StreamingService {
  final String name;
  final String logoUrl; // Use asset paths for local images
  StreamingService(this.name, this.logoUrl);
}

// Example list of services (You MUST add these logos to your 'assets' folder)
final List<StreamingService> services = [
  StreamingService('Netflix', 'https://upload.wikimedia.org/wikipedia/commons/e/ea/Netflix_Logomark.png'),
  StreamingService('Hulu', 'https://download.logo.wine/logo/Hulu/Hulu-Logo.wine.png'),
  StreamingService('Apple TV+', 'https://upload.wikimedia.org/wikipedia/commons/9/99/AppleTV.png'),
  StreamingService('Disney+', 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Disney%2B_logo.svg/1200px-Disney%2B_logo.svg.png'),
  StreamingService('Prime Video', 'https://1000logos.net/wp-content/uploads/2022/10/Amazon-Prime-Video-Logo.png'),
  StreamingService('Max', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSVY1YgDtoCGkabTHsZntBp6MaRpEX414R0ew&s'),
  StreamingService('Peacock', 'https://www.freelogovectors.net/wp-content/uploads/2023/09/peacock-logo-freelogovectors.net_.net_.png'),
  StreamingService('Paramount+', 'https://logowik.com/content/uploads/images/paramount-plus5224.jpg'),
];


class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  final Set<String> _selectedServices = {};
  
  void _toggleServiceSelection(String name) {
    setState(() {
      if (_selectedServices.contains(name)) {
        _selectedServices.remove(name);
      } else {
        _selectedServices.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // --- Main Scrollable Content Area ---
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 20.0,
                left: 25.0,
                right: 25.0,
                bottom: 160.0, // Space for the fixed bottom bar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Progress Bar and Step (Step 3 of 4, 75%)
                  const SizedBox(height: 25),
                  _buildProgressHeader(),
                  const SizedBox(height: 25),

                  // 2. Title and Subtitle
                  const Text(
                    'Your streaming\nservices',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We\'ll only recommend shows you can actually watch.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 3. Search Bar
                  _buildSearchBar(),
                  const SizedBox(height: 25),

                  // 4. Service Logo Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15.0,
                      mainAxisSpacing: 15.0,
                      childAspectRatio: 2.0, // Wider aspect ratio for logo tiles
                    ),
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final isSelected = _selectedServices.contains(service.name);

                      return ServiceLogoTile(
                        service: service,
                        isSelected: isSelected,
                        onTap: () => _toggleServiceSelection(service.name),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // --- Fixed Bottom Button Bar ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomButtonBar(context),
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
                value: 0.75, // 75% progress for Step 3 of 4
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 15),
            const Text(
              '75%',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Step 3 of 4',
          style: TextStyle(
            color: primaryGreen,
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
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: '', // Placeholder is empty in the image
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 15),
        ),
      ),
    );
  }

  // Helper widget for the bottom buttons
  Widget _buildBottomButtonBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 25.0,
        right: 25.0,
        top: 15.0,
        bottom: MediaQuery.of(context).padding.bottom + 15,
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
                print('Selected Services: $_selectedServices');
                Navigator.pushReplacementNamed(context, 'welcome');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
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

// --- Helper Widget: The Individual Service Logo Tile ---
class ServiceLogoTile extends StatelessWidget {
  final StreamingService service;
  final bool isSelected;
  final VoidCallback onTap;

  const ServiceLogoTile({
    super.key,
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Image.network(
          service.logoUrl,
          fit: BoxFit.contain,
          // Use color tinting for the Apple TV+ logo if it's a monochrome image
          
        ),
      ),
    );
  }
}

// NOTE: Before running, ensure you have set up your 'assets/images/' folder
// and declared it in pubspec.yaml. 
/* // pubspec.yaml example:
flutter:
  assets:
    - assets/netflix_logo.png
    - assets/hulu_logo.png
    # ... and so on for all logos
*/

// void main() {
//   runApp(const MaterialApp(home: ServiceSelectionScreen()));
// }