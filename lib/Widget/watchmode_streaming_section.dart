import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/services/watchmode_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays streaming providers using Watchmode API
class WatchmodeStreamingSection extends StatefulWidget {
  final String tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final String title;

  const WatchmodeStreamingSection({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
  });

  @override
  State<WatchmodeStreamingSection> createState() =>
      _WatchmodeStreamingSectionState();
}

class _WatchmodeStreamingSectionState extends State<WatchmodeStreamingSection> {
  final WatchmodeService _watchmodeService = WatchmodeService();
  List<StreamingProvider>? _providers;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final providers = await _watchmodeService.getStreamingProviders(
        widget.tmdbId,
        widget.mediaType,
      );
      if (mounted) {
        setState(() {
          _providers = providers;
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

  Future<void> _openProvider(StreamingProvider provider) async {
    if (provider.webLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No link available for ${provider.name}')),
      );
      return;
    }

    final uri = Uri.parse(provider.webLink);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open ${provider.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening ${provider.name}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return const SizedBox.shrink(); // Silently hide on error
    }

    if (_providers == null || _providers!.isEmpty) {
      return _buildEmptyState();
    }

    // Filter to show only subscription and free providers first
    final subscriptionProviders = _providers!
        .where((p) => p.type == 'sub' || p.type == 'free')
        .toList();

    final rentBuyProviders = _providers!
        .where((p) => p.type == 'rent' || p.type == 'buy')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subscriptionProviders.isNotEmpty) ...[
          const Text(
            "Stream On",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subscriptionProviders.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildProviderBadge(subscriptionProviders[index]);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (rentBuyProviders.isNotEmpty) ...[
          Text(
            subscriptionProviders.isEmpty ? "Rent or Buy" : "Also Available",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rentBuyProviders.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildProviderBadge(
                  rentBuyProviders[index],
                  compact: true,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProviderBadge(
    StreamingProvider provider, {
    bool compact = false,
  }) {
    final size = compact ? 40.0 : 50.0;
    final textWidth = compact ? 50.0 : 60.0;

    return GestureDetector(
      onTap: () => _openProvider(provider),
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
              child: provider.logoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: provider.logoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade800,
                        child: Center(
                          child: Text(
                            provider.name.isNotEmpty
                                ? provider.name[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade800,
                      child: Center(
                        child: Text(
                          provider.name.isNotEmpty
                              ? provider.name[0].toUpperCase()
                              : "?",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: textWidth,
              child: Text(
                provider.name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Stream On",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Streaming",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Text(
                "Not currently available for streaming in the US",
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
