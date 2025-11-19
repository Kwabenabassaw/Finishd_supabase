import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GenericMovieCard<T> extends StatelessWidget {
  final T item;
  final String Function(T) titleBuilder;
  final String Function(T) posterBuilder;
  final String Function(T)? typeBuilder;
  final VoidCallback? onTap;

  const GenericMovieCard({
    super.key,
    required this.item,
    required this.titleBuilder,
    required this.posterBuilder,
    this.typeBuilder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: posterBuilder(item),
                  fit: BoxFit.cover,
                  height: 180,
                  width: 140,
                  placeholder: (context, url) =>
                      Container(color: Colors.grey[300]),
                  errorWidget: (context, url, error) =>
                      Container(color: Colors.grey, child: const Icon(Icons.error)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                titleBuilder(item),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (typeBuilder != null)
                Text(
                  typeBuilder!(item),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
