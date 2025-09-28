import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheManager extends CacheManager {
  static const key = 'kickHiveCache';

  ImageCacheManager()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30), // Extend TTL to 30 days
            maxNrOfCacheObjects: 500, // Optional: increase cache size
          ),
        );
}
