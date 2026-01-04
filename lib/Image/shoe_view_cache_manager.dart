import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ShoeViewCacheManager extends CacheManager {
  static const key = 'shoe_view_cache';

  static final ShoeViewCacheManager _instance =
      ShoeViewCacheManager._internal();

  factory ShoeViewCacheManager() => _instance;

  ShoeViewCacheManager._internal()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 500,
        ),
      );

  Future<File?> getCachedOrDownloadFile(String url) async {
    try {
      final file = await getSingleFile(url);
      final exists = await file.exists(); // ✅ async check
      return exists ? file : null;
    } catch (e) {
      print('Cache retrieval failed: $e');
      return null;
    }
  }

  Future<File?> getCachedFileOnly(String url) async {
    // getFileFromCache is purely local and doesn't trigger a network call
    final FileInfo? fileInfo = await getFileFromCache(url);

    if (fileInfo != null && await fileInfo.file.exists()) {
      return fileInfo.file;
    }
    return null;
  }
}
