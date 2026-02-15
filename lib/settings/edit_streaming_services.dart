import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/LoadingWidget/LogoLoading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/Model/user_preferences.dart';
import 'package:finishd/services/user_preferences_service.dart';
import 'package:finishd/tmbd/getproviders.dart';

const Color primaryGreen = Color(0xFF1A8927);

class EditStreamingServicesScreen extends StatefulWidget {
  const EditStreamingServicesScreen({super.key});

  @override
  State<EditStreamingServicesScreen> createState() =>
      _EditStreamingServicesScreenState();
}

class _EditStreamingServicesScreenState
    extends State<EditStreamingServicesScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();
  final Getproviders _getProviders = Getproviders();

  List<WatchProvider>? _allServices;
  final Set<int> _selectedProviderIds = {};
  final Map<int, SelectedProvider> _selectedProvidersMap = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      // Load all available services and user's current preferences in parallel
      final results = await Future.wait([
        _getProviders.getMovieprovide(),
        _prefsService.getUserPreferences(userId),
      ]);

      final services = results[0] as List<WatchProvider>;
      final prefs = results[1] as UserPreferences?;

      // Build the selected providers map from existing preferences
      if (prefs != null) {
        for (final provider in prefs.streamingProviders) {
          _selectedProviderIds.add(provider.providerId);
          _selectedProvidersMap[provider.providerId] = provider;
        }
      }

      if (mounted) {
        setState(() {
          _allServices = services;
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

  void _toggleProvider(WatchProvider service) {
    setState(() {
      if (_selectedProviderIds.contains(service.providerId)) {
        _selectedProviderIds.remove(service.providerId);
        _selectedProvidersMap.remove(service.providerId);
      } else {
        _selectedProviderIds.add(service.providerId);
        _selectedProvidersMap[service.providerId] = SelectedProvider(
          providerId: service.providerId,
          providerName: service.providerName,
          logoPath: service.logoPath ?? '',
        );
      }
    });
  }

  Future<void> _saveChanges() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final providers = _selectedProvidersMap.values
          .map((p) => p.toJson())
          .toList();

      await _prefsService.updateStreamingProviders(userId, providers);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Streaming services updated!'),
            backgroundColor: primaryGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming Services'),
        centerTitle: true,
        actions: [
          if (!_isLoading && _allServices != null)
            TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryGreen,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your streaming services',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the services you use to get personalized recommendations.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_selectedProviderIds.length} selected',
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.85,
            ),
            itemCount: _allServices!.length,
            itemBuilder: (context, index) {
              final service = _allServices![index];
              final isSelected = _selectedProviderIds.contains(
                service.providerId,
              );

              return _ServiceTile(
                service: service,
                isSelected: isSelected,
                onTap: () => _toggleProvider(service),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final WatchProvider service;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: CachedNetworkImage(
                  imageUrl:
                      "https://image.tmdb.org/t/p/w500${service.logoPath}",
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: LogoLoadingScreen()),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.tv, color: Colors.grey),
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
              color: isSelected ? primaryGreen : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
