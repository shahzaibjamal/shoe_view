class AppConstants {
  // Cache
  static const int maxCacheSize = 500;
  static const Duration cacheStalePeriod = Duration(days: 60);
  
  // UI
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Search
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);
  
  // Network
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  // Pagination
  static const int itemsPerPage = 20;
  static const int imageWarmupCount = 20;
  static const int imageBatchSize = 5;
  
  // Image
  static const double defaultImageSize = 100.0;
  static const double listItemImageSize = 60.0;
}
