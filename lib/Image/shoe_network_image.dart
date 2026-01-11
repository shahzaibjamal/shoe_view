import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';

class ShoeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? height; // Changed to nullable for better layout flexibility
  final double? width;
  final BoxFit fit;

  const ShoeNetworkImage({
    super.key,
    required this.imageUrl,
    this.height = 100,
    this.width = 100,
    this.fit =
        BoxFit.cover, // Changed default to cover for better collage looks
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    // Use the static helper from our manager for consistency
    final stableKey = ShoeViewCacheManager.getStableKey(imageUrl);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: stableKey,
      cacheManager:
          ShoeViewCacheManager(), // 🎯 Ensures it uses our 60-day config
      height: height,
      width: width,
      fit: fit,
      // 🎯 This is key for offline: if the URL changes (token change),
      // it keeps showing the one it has in cache for that stableKey.
      useOldImageOnUrlChange: true,

      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        // Double-check: If CachedNetworkImage fails, try one last manual check
        return FutureBuilder<File?>(
          future: ShoeViewCacheManager().getCachedFileOnly(url),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.file(
                snapshot.data!,
                height: height,
                width: width,
                fit: fit,
              );
            }
            return _buildErrorWidget();
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[300],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
