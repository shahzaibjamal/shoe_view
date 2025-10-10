import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shoe_view/Image/shoe_view_cache_manager.dart';

class ShoeNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final double width;
  final BoxFit fit;

  const ShoeNetworkImage({super.key, 
    required this.imageUrl,
    this.height = 100,
    this.width = 100,
    this.fit = BoxFit.fitWidth,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: ShoeViewCacheManager(),
      placeholder: (context, url) => Container(
        height: height,
        width: width,
        color: Colors.grey[300],
      ),
      errorWidget: (context, url, error) => Icon(Icons.error),
      height: height,
      width: width,
      fit: fit,
    );
  }
}
