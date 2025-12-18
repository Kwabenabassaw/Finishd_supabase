import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/Model/movieprovider.dart';
import 'package:finishd/tmbd/getproviders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<WatchProvider>? _cachedServices;
  bool _isLoading = true;
  String? _error;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<WatchProvider> get _filteredServices {
    if (_cachedServices == null) return [];
    if (_searchQuery.isEmpty) return _cachedServices!;
    return _cachedServices!
        .where(
          (service) =>
              service.providerName.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  Future<void> _loadServices() async {
    try {
      final services = await getprovider.getMovieprovide();
      if (mounted) {
        setState(() {
          _cachedServices = services;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingProvider = Provider.of<OnboardingProvider>(
      context,
      listen: true,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                  Text(
                    'Your streaming\nservices',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We\'ll only recommend shows you can actually watch.',
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  _buildSearchBar(),
                  const SizedBox(height: 25),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Text('Error: $_error')
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 15.0,
                                mainAxisSpacing: 15.0,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: _filteredServices.length,
                          itemBuilder: (context, index) {
                            final service = _filteredServices[index];
                            final isSelected = onboardingProvider
                                .isProviderSelected(service.providerId);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search streaming services...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 15),
        ),
      ),
    );
  }

  Widget _buildBottomButtonBar(BuildContext context) {
    final onboardingProvider = Provider.of<OnboardingProvider>(
      context,
      listen: false,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.white,
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
                HapticFeedback.mediumImpact();
                if (onboardingProvider.selectedProviders.isNotEmpty) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final success = await onboardingProvider.saveToFirestore();

                  Navigator.of(context).pop();

                  if (success) {
                    print('Successfully saved preferences!');
                    print(
                      'Selected Genres: ${onboardingProvider.selectedGenres}',
                    );
                    print(
                      'Selected Movies/Shows: ${onboardingProvider.selectedMovies.length + onboardingProvider.selectedShows.length}',
                    );
                    print(
                      'Selected Providers: ${onboardingProvider.selectedProviders}',
                    );
                    Navigator.pushReplacementNamed(context, 'welcome');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to save preferences: ${onboardingProvider.errorMessage}',
                        ),
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
              HapticFeedback.lightImpact();
              print('Skipped this step');
              Navigator.pushReplacementNamed(context, 'welcome');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? primaryGreen : Colors.grey.shade300,
                width: isSelected ? 3.0 : 2.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: ClipOval(
              child: Container(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                padding: const EdgeInsets.all(12),
                child: CachedNetworkImage(
                  imageUrl:
                      "https://image.tmdb.org/t/p/w500${service.logoPath}",
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                    child: LogoLoadingScreen(),
                  ),
                  errorWidget: (context, url, error) =>
                      Image.asset("assets/noimage.jpg", fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.providerName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? primaryGreen
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
