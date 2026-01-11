import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ShoeViewCacheManager extends CacheManager {
  static const String _key = 'shoe_view_cache';

  // Singleton instance
  static final ShoeViewCacheManager _instance =
      ShoeViewCacheManager._internal();
  factory ShoeViewCacheManager() => _instance;

  ShoeViewCacheManager._internal()
    : super(
        Config(
          _key,
          stalePeriod: const Duration(days: 60),
          maxNrOfCacheObjects: 500,
          // 🎯 ADD THIS: This helps the cache manager understand
          // it should prioritize existing files when offline.
          repo: JsonCacheInfoRepository(databaseName: _key),
        ),
      );

  /// Helper to strip tokens consistently across the app
  static String getStableKey(String url) {
    if (url.isEmpty) return "";
    return url.split('?').first;
  }

  Future<File?> getCachedOrDownloadFile(String url, {String? customKey}) async {
    final String cacheKey = customKey ?? getStableKey(url);

    try {
      // 1. Check local cache first
      final FileInfo? fileInfo = await getFileFromCache(cacheKey);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return fileInfo.file;
      }

      // 2. Download if missing (only if internet is available)
      final file = await getSingleFile(url, key: cacheKey);
      return await file.exists() ? file : null;
    } catch (e) {
      return null;
    }
  }

  Future<File?> getCachedFileOnly(String url, {String? customKey}) async {
    final String cacheKey = customKey ?? getStableKey(url);
    final FileInfo? fileInfo = await getFileFromCache(cacheKey);
    if (fileInfo != null && await fileInfo.file.exists()) {
      return fileInfo.file;
    }
    return null;
  }
}
