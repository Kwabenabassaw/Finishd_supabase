import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GenericMovieCard<T> extends StatelessWidget {
  final T item;
  final String Function(T) titleBuilder;
  final String Function(T) posterBuilder;
  final String Function(T)? typeBuilder;
  final Widget? socialBadge; // New parameter for social signals
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
    this.socialBadge,
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
      onLongPress: onActionMenuTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CachedNetworkImage(
                        imageUrl: posterBuilder(item),
                        fit: BoxFit.cover,
                        height: imgHeight,
                        width: cardWidth,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[900],
                          height: imgHeight,
                          width: cardWidth,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[850],
                          height: imgHeight,
                          width: cardWidth,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onActionMenuTap != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onActionMenuTap,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white12,
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  if (socialBadge != null)
                    Positioned(bottom: 8, left: 8, child: socialBadge!),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                titleBuilder(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
              if (typeBuilder != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    typeBuilder!(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
