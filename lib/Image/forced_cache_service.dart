import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ForcedCacheService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    final response = await super.get(url, headers: headers);
    return ForcedCacheResponse(response);
  }
}

class ForcedCacheResponse implements FileServiceResponse {
  final FileServiceResponse _inner;
  ForcedCacheResponse(this._inner);

  @override
  int get statusCode => _inner.statusCode;

  // 🎯 This is the magic: Force the app to treat the file as valid for 60 days
  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 60));

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  String get fileExtension => _inner.fileExtension;

  @override
  String? get eTag => _inner.eTag;
}