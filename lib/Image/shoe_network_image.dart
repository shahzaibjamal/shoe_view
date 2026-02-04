import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:shoe_view/app_status_notifier.dart';
import 'package:shoe_view/Services/connectivity_service.dart';

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

    // 🎯 Watch app status to rebuild when sync permissions change (e.g., from global dialog)
    context.watch<AppStatusNotifier>();
    
    // Use the static helper from our manager for consistency
    final stableKey = ShoeViewCacheManager.getStableKey(imageUrl);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: FutureBuilder<File?>(
        key: ValueKey('cache_future_${stableKey}_${imageUrl.hashCode}'),
        future: _checkSyncStatus(context, imageUrl, stableKey),
        builder: (context, syncSnapshot) {
          if (syncSnapshot.hasData && syncSnapshot.data != null) {
            return _buildClipped(
              _FadeInImage(
                child: Image.file(
                  syncSnapshot.data!,
                  height: height,
                  width: width,
                  fit: fit,
                  cacheWidth: disableMemCache || width == null 
                      ? null 
                      : (width! * 2.5).toInt(),
                ),
              ),
            );
          }

          if (syncSnapshot.hasError && syncSnapshot.error == 'SYNC_PAUSED') {
            return _buildClipped(_buildSyncPausedWidget());
          }

          // While checking cache, show placeholder
          if (syncSnapshot.connectionState == ConnectionState.waiting) {
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

  Future<File?> _checkSyncStatus(BuildContext context, String url, String key) async {
    final cached = await ShoeViewCacheManager().getCachedFileOnly(url, customKey: key);
    if (cached != null) return cached;

    final appStatus = Provider.of<AppStatusNotifier>(context, listen: false);
    if (appStatus.allowMobileDataSync || appStatus.sessionMobileSyncAllowed) {
      return null;
    }

    final isWifi = await ConnectivityService().isWifi();
    if (isWifi) return null;

    throw 'SYNC_PAUSED';
  }

  Widget _buildSyncPausedWidget() {
    return Container(
      height: height ?? 200,
      width: width,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.signal_wifi_off_rounded, size: 20, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text(
            'Sync Paused',
            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
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
