import 'package:cached_network_image/cached_network_image.dart';
import 'package:finishd/services/deep_link_service.dart';
import 'package:finishd/Model/streaming_availability.dart';
import 'package:flutter/material.dart';

class StreamingBadge extends StatelessWidget {
  final ServiceLink service;
  final String title;
  final String tmdbId;
  final DeepLinkService _deepLinkService = DeepLinkService();

  StreamingBadge({
    super.key,
    required this.service,
    required this.title,
    required this.tmdbId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _deepLinkService.launchProvider(
          providerId: 0, // Not strictly needed if directUrl is present
          providerName: service.name ?? "Streaming Service",
          title: title,
          directUrl: service.videoLink ?? service.link,
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
              child: service.logoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: service.logoUrl!,
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
                    )
                  : Container(
                      color: Colors.grey.shade800,
                      child: Center(
                        child: Text(
                          (service.name ?? "?")[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              service.name ?? "Provider",
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
