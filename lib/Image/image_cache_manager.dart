import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ShoeViewCacheManager extends CacheManager {
  static const key = 'shoe_view_cache';

  ShoeViewCacheManager()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 30), // Extend TTL to 30 days
            maxNrOfCacheObjects: 500, // Optional: increase cache size
          ),
        );
}
