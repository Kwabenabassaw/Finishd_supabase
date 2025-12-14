import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/Model/Watchprovider.dart';
import 'package:finishd/services/deep_link_service.dart';
import 'package:flutter/material.dart';

class StreamingBadge extends StatelessWidget {
  final WatchProvider provider;
  final String title;
  final String tmdbId;
  final DeepLinkService _deepLinkService = DeepLinkService();
  final String? webUrl;

  StreamingBadge({
    super.key,
    required this.provider,
    required this.title,
    required this.tmdbId,
    this.webUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _deepLinkService.launchProvider(
          providerId: provider.providerId,
          providerName: provider.providerName,
     
          title: title,
        );
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl:
                    "https://image.tmdb.org/t/p/original${provider.logoPath}",
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              provider.providerName,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
