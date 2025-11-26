import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GenericMovieCard<T> extends StatelessWidget {
  final T item;
  final String Function(T) titleBuilder;
  final String Function(T) posterBuilder;
  final String Function(T)? typeBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onActionMenuTap; // New callback for action menu
  final double? width;
  final double? imageHeight;

  const GenericMovieCard({
    super.key,
    required this.item,
    required this.titleBuilder,
    required this.posterBuilder,
    this.typeBuilder,
    this.onTap,
    this.onActionMenuTap, // New parameter
    this.width,
    this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = width ?? 140.0;
    final imgHeight = imageHeight ?? 180.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onActionMenuTap, // Long press opens action menu
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Movie poster with three-dot overlay
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: posterBuilder(item),
                      fit: BoxFit.cover,
                      height: imgHeight,
                      width: cardWidth,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        height: imgHeight,
                        width: cardWidth,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey,
                        height: imgHeight,
                        width: cardWidth,
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),

                  // Three-dot menu icon overlay (if action menu enabled)
                  if (onActionMenuTap != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onActionMenuTap,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                titleBuilder(item),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (typeBuilder != null)
                Text(
                  typeBuilder!(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
