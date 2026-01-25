import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;

/// Centralized avatar component with proper fallback hierarchy:
/// 1. Profile image (if available and loads successfully)
/// 2. Initials from firstName + lastName
/// 3. Initials from firstName only
/// 4. First character of username
/// 5. Finishd logo icon (final fallback)
class UserAvatar extends StatelessWidget {
  final String? profileImageUrl;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String userId; // For deterministic background color
  final double radius;
  final bool showBorder;
  final Color? borderColor;

  const UserAvatar({
    super.key,
    this.profileImageUrl,
    this.firstName,
    this.lastName,
    this.username,
    required this.userId,
    this.radius = 20,
    this.showBorder = false,
    this.borderColor,
  });

  /// Generate initials from available name fields
  String _getInitials() {
    // Try firstName + lastName
    if (firstName != null && firstName!.trim().isNotEmpty) {
      final first = firstName!.trim();
      if (lastName != null && lastName!.trim().isNotEmpty) {
        final last = lastName!.trim();
        return '${first[0]}${last[0]}'.toUpperCase();
      }
      // firstName only
      return first[0].toUpperCase();
    }

    // Fallback to username
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim()[0].toUpperCase();
    }

    // No initials available - will trigger logo fallback
    return '';
  }

  /// Generate deterministic background color from userId
  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Hash userId to get consistent color
    final hash = userId.hashCode;
    final hue = (hash % 360).toDouble();
    
    // Use HSL for better color control
    return HSLColor.fromAHSL(
      1.0,
      hue,
      isDark ? 0.5 : 0.6, // Saturation
      isDark ? 0.4 : 0.5, // Lightness
    ).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initials = _getInitials();
    final backgroundColor = _getBackgroundColor(context);

    // Generate optimized thumbnail URL if possible
    final String? thumbnailUrl = _getThumbnailUrl(profileImageUrl);

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      // Use CachedNetworkImageProvider for aggressive caching & offline support
      backgroundImage: thumbnailUrl != null && thumbnailUrl.isNotEmpty
          ? CachedNetworkImageProvider(
              thumbnailUrl,
              // Optimize memory by resizing decoded image to reasonable avatar size
              // even if the download is larger.
              maxWidth: (radius * 4).toInt(), // 2x density * 2 (safety)
              maxHeight: (radius * 4).toInt(),
            )
          : null,
      onBackgroundImageError: thumbnailUrl != null && thumbnailUrl.isNotEmpty
          ? (exception, stackTrace) {
              // Image failed to load - will show initials/logo fallback automatically
              // because backgroundImage will be null in the painting context effectively
              debugPrint('[UserAvatar] Failed to load image: $thumbnailUrl');
            }
          : null,
      child: thumbnailUrl == null || thumbnailUrl.isEmpty
          ? _buildFallbackContent(context, initials, isDark)
          : null, // If image loads, child is covered. If fails, CircleAvatar shows bg color, we want fallback text.
                  // Actually CircleAvatar doesn't auto-show child on error for backgroundImage.
                  // We need to handle this better.
                  // Better approach: Use CachedNetworkImage widget inside `child` with `fit: BoxFit.cover` and `ClipOval`.
    );

    // Better implementation using ClipOval + CachedNetworkImage for full control over Loading/Error states
    avatar = ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: backgroundColor,
        child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: (radius * 4).toInt(),
                memCacheHeight: (radius * 4).toInt(),
                placeholder: (context, url) =>
                    _buildFallbackContent(context, initials, isDark),
                errorWidget: (context, url, error) =>
                    _buildFallbackContent(context, initials, isDark),
              )
            : Center(child: _buildFallbackContent(context, initials, isDark)),
      ),
    );

    // Add border if requested
    if (showBorder) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? (isDark ? Colors.white24 : Colors.black12),
            width: 2,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }

  /// Build fallback content (initials or logo)
  Widget _buildFallbackContent(BuildContext context, String initials, bool isDark) {
    if (initials.isNotEmpty) {
      // Show initials
      return Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.6, // Scale font size with radius
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
    }

    // Final fallback: Show Finishd logo icon
    return Icon(
      Icons.person, // TODO: Replace with actual Finishd logo asset
      color: isDark ? Colors.white70 : Colors.white,
      size: radius * 0.8,
    );
  }

  /// Optimizes Cloudinary URLs for thumbnail usage
  String? _getThumbnailUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Cloudinary optimization
    if (url.contains('res.cloudinary.com')) {
      // If already has transformation, unlikely, but we can try to inject/replace
      // Standard structure: /upload/v<version>/<id>
      // We want: /upload/w_200,h_200,c_fill,q_auto/v<version>/<id>
      
      // Check if we haven't already added transformations (simple check)
      if (!url.contains('/w_') && !url.contains(',w_')) {
        return url.replaceFirst('/upload/', '/upload/w_200,h_200,c_fill,q_auto/');
      }
    }

    return url;
  }
}

/// Variant for community/show avatars (uses poster images)
class CommunityAvatar extends StatelessWidget {
  final String? posterPath;
  final String title;
  final double radius;
  final bool showBorder;

  const CommunityAvatar({
    super.key,
    this.posterPath,
    required this.title,
    this.radius = 28,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
      backgroundImage: posterPath != null
          ? NetworkImage('https://image.tmdb.org/t/p/w200$posterPath')
          : null,
      child: posterPath == null
          ? Icon(
              Icons.movie,
              color: isDark ? Colors.white70 : Colors.grey[700],
              size: radius * 0.7,
            )
          : null,
    );

    if (showBorder) {
      avatar = Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF1A8927), Colors.blueAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
