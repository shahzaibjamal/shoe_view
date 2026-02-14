import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shoe_view/Image/forced_cache_service.dart';

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
          maxNrOfCacheObjects: 2000, // ⬆️ Increased from 500
          fileService: ForcedCacheService(),
        ),
      );

  /// Helper to strip tokens and size parameters consistently
  static String getStableKey(String url) {
    if (url.isEmpty) return "";
    // 1. Strip query parameters
    String base = url.split('?').first;
    // 2. Strip Google width/height parameters (e.g., =w400, -w400, =s400)
    // Matches patterns like =w1200, =s400, -w800 at the end or followed by other params
    return base.replaceAll(RegExp(r'=[ws]\d+$'), '').replaceAll(RegExp(r'-[ws]\d+$'), '');
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
