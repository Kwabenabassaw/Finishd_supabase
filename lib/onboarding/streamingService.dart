import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/Model/movieprovider.dart';
import 'package:finishd/tmbd/getproviders.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:provider/provider.dart';
import 'package:finishd/provider/onboarding_provider.dart';

// Define the primary green color
const Color primaryGreen = Color((0xFF1A8927));

Getproviders getprovider = Getproviders();

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final onboardingProvider = Provider.of<OnboardingProvider>(context, listen: true);

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
                bottom: 160.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),
                  _buildProgressHeader(),
                  const SizedBox(height: 25),
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
                  _buildSearchBar(),
                  const SizedBox(height: 25),
                  FutureBuilder(
                    future: getprovider.getMovieprovide(),
                    builder: (context, asyncSnapshot) {
                      if (asyncSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (asyncSnapshot.hasError) {
                        return Text('Error: ${asyncSnapshot.error}');
                      }
                      final services = asyncSnapshot.data!;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15.0,
                          mainAxisSpacing: 15.0,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final service = services[index];
                          final isSelected = onboardingProvider.isProviderSelected(service.providerId);
                          return ServiceLogoTile(
                            service: service,
                            isSelected: isSelected,
                            onTap: () {
                              final provider = SelectedProvider(
                                providerId: service.providerId,
                                providerName: service.providerName,
                                logoPath: service.logoPath ?? '',
                              );
                              onboardingProvider.toggleProvider(provider);
                            },
                          );
                        },
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

  Widget _buildProgressHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: 0.75,
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
          hintText: '',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.only(top: 15),
        ),
      ),
    );
  }

  Widget _buildBottomButtonBar(BuildContext context) {
    final onboardingProvider = Provider.of<OnboardingProvider>(context, listen: false);

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
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () async {
                if (onboardingProvider.selectedProviders.isNotEmpty) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator()),
                  );

                  final success = await onboardingProvider.saveToFirestore();

                  Navigator.of(context).pop();

                  if (success) {
                    print('Successfully saved preferences!');
                    print('Selected Genres: ${onboardingProvider.selectedGenres}');
                    print(
                        'Selected Movies/Shows: ${onboardingProvider.selectedMovies.length + onboardingProvider.selectedShows.length}');
                    print('Selected Providers: ${onboardingProvider.selectedProviders}');
                    Navigator.pushReplacementNamed(context, 'welcome');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save preferences: ${onboardingProvider.errorMessage}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: onboardingProvider.isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
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

class ServiceLogoTile extends StatelessWidget {
  final WatchProvider service;
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
        child: CachedNetworkImage(
          imageUrl: "https://image.tmdb.org/t/p/w500${service.logoPath}",
          fit: BoxFit.fill,
          width: double.infinity,
          height: double.infinity,
          errorWidget: (context, url, error) => Image.asset("assets/noimage.jpg"),
        ),
      ),
    );
  }
}
