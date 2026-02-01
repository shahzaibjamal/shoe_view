import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';

class ShoeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final bool disableMemCache;
  final BorderRadius? borderRadius;

  const ShoeNetworkImage({
    super.key,
    required this.imageUrl,
    this.height = 100,
    this.width = 100,
    this.fit = BoxFit.cover,
    this.disableMemCache = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildClipped(_buildErrorWidget());
    }

    // Use the static helper from our manager for consistency
    final stableKey = ShoeViewCacheManager.getStableKey(imageUrl);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: FutureBuilder<File?>(
        key: ValueKey('cache_future_${stableKey}_${imageUrl.hashCode}'),
        future: ShoeViewCacheManager().getCachedFileOnly(imageUrl, customKey: stableKey),
        builder: (context, cacheSnapshot) {
          // If we have a cached file, use it directly (no network hit!)
          if (cacheSnapshot.connectionState == ConnectionState.done &&
              cacheSnapshot.hasData &&
              cacheSnapshot.data != null) {
            // 🎯 Soft fade-in for cached images
            return _buildClipped(
              _FadeInImage(
                child: Image.file(
                  cacheSnapshot.data!,
                  height: height,
                  width: width,
                  fit: fit,
                  // 🎯 Optimization: Resize in memory similar to CachedNetworkImage
                  cacheWidth: disableMemCache || width == null 
                      ? null 
                      : (width! * 2.5).toInt(),
                ),
              ),
            );
          }

          // While checking cache, show placeholder
          if (cacheSnapshot.connectionState == ConnectionState.waiting) {
            return _buildClipped(_buildPlaceholder());
          }

          // No cached file found - fall back to CachedNetworkImage for download
          return _buildNetworkImage(stableKey);
        },
      ),
    );
  }

  /// Build the CachedNetworkImage widget (only used when no local cache exists)
  Widget _buildNetworkImage(String stableKey) {
    // 🎯 Optimization: Resize image in memory to save RAM
    // If disableMemCache is true, we want the FULL resolution (for collage generation)
    final int? memCacheWidth =
        disableMemCache || width == null ? null : (width! * 2.5).toInt();

    String processedUrl = imageUrl;
    if (disableMemCache && imageUrl.contains('googleusercontent.com')) {
      // For high-res collage, request 1200px from Google servers
      processedUrl = imageUrl.replaceAll(RegExp(r'=w\d+'), '=w1200');
    }

    return CachedNetworkImage(
      imageUrl: processedUrl,
      cacheKey: stableKey,
      cacheManager: ShoeViewCacheManager(),
      height: height,
      width: width,
      fit: fit,
      memCacheWidth: memCacheWidth,
      // 🎯 Fix: Disable "ghosting". If the URL changes (e.g., during search), 
      // show the placeholder immediately instead of keeping the previous shoe's image.
      useOldImageOnUrlChange: false,
      // 🎯 Soft fade-in animation for newly downloaded images
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      
      // 🎯 Fix: Use imageBuilder to apply borderRadius during paint/fade
      imageBuilder: (context, imageProvider) {
        // Use ClipRRect around an Image widget so it sizes to the content
        // rather than filling the container like DecorationImage does.
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image(
            image: imageProvider,
            fit: fit,
          ),
        );
      },

      placeholder: (context, url) => _buildClipped(_buildPlaceholder()),
      
      errorWidget: (context, url, error) {
        return FutureBuilder<File?>(
          future: ShoeViewCacheManager().getCachedFileOnly(url),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              // Local fallback image
              return _buildClipped(
                Image.file(
                  snapshot.data!,
                  height: height,
                  width: width,
                  fit: fit,
                ),
              );
            }
            return _buildClipped(_buildErrorWidget());
          },
        );
      },
    );
  }

  // 🎯 Helper to apply border radius to non-image widgets (placeholders/errors)
  Widget _buildClipped(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(
      borderRadius: borderRadius!,
      child: child,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: height ?? 200, // 🎯 Sensible minimum height during loading if not specified
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
      height: height ?? 200,
      width: width,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}

/// 🎯 Helper widget for soft fade-in animation on cached images
class _FadeInImage extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _FadeInImage({
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<_FadeInImage> createState() => _FadeInImageState();
}

class _FadeInImageState extends State<_FadeInImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: widget.child,
    );
  }
}
