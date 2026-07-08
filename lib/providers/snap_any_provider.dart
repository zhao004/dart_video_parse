part of '../providers.dart';

class SnapAnyProvider extends _JsonProvider {
  const SnapAnyProvider();

  static const _siteUrl = 'https://snapany.com';
  static const _apiUrl = 'https://api.snapany.com/v1/extract/post';
  static const _locale = 'zh';
  static const _footerSalt = '6HTugjCXxR';

  @override
  VideoParseProvider get provider => VideoParseProvider.snapany;

  @override
  String get displayName => 'SnapAny';

  @override
  int get priority => 18;

  @override
  String get baseUrl => _siteUrl;

  @override
  String get probeUrl => 'https://api.snapany.com/';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final signature = ParseUtils.md5Hex('$url$_locale$timestamp$_footerSalt');
    final response = await client.post<Object?>(
      _apiUrl,
      data: {'link': url},
      options: Options(
        headers: browserHeaders(
          accept: 'application/json, text/plain, */*',
          contentType: 'application/json',
          origin: _siteUrl,
          referer: '$_siteUrl/zh',
          extra: {
            'Accept-Language': _locale,
            'G-Timestamp': '$timestamp',
            'G-Footer': signature,
          },
        ),
      ),
    );
    final payload = asMap(response.data, 'SnapAny 返回空数据');
    if (payload['code'] != null && payload['code'].toString() != '0') {
      throw ProviderException(
        safeString(payload['message'], defaultValue: 'SnapAny 解析失败'),
      );
    }
    return _normalize(payload, url);
  }

  ParseResult _normalize(Map<String, Object?> payload, String sourceUrl) {
    final medias = ParseUtils.listValue(payload['medias']);
    if (medias.isEmpty) {
      throw const ProviderException('SnapAny 未返回媒体资源');
    }
    final videos = <VideoItem>[];
    final images = <ImageItem>[];
    final seen = <String>{};
    var cover = '';
    for (final media in medias) {
      final map = ParseUtils.mapValue(media);
      final mediaType = safeString(map['media_type']).toLowerCase();
      final resourceUrl = safeString(map['resource_url']);
      final previewUrl = safeString(map['preview_url']);
      cover = cover.isEmpty
          ? (previewUrl.isEmpty ? resourceUrl : previewUrl)
          : cover;
      if (mediaType == 'video') {
        if (resourceUrl.isNotEmpty && seen.add(resourceUrl)) {
          videos.add(VideoItem(url: resourceUrl, quality: '默认'));
        }
        for (final item in ParseUtils.listValue(map['formats'])) {
          final format = ParseUtils.mapValue(item);
          final videoUrl = safeString(format['video_url']);
          if (videoUrl.isNotEmpty && seen.add(videoUrl)) {
            videos.add(
              VideoItem(
                url: videoUrl,
                quality: safeString(
                  format['quality_note'] ?? format['quality'],
                  defaultValue: '默认',
                ),
              ),
            );
          }
        }
      } else if (resourceUrl.isNotEmpty) {
        images.add(ImageItem(url: resourceUrl));
      } else if (previewUrl.isNotEmpty) {
        images.add(ImageItem(url: previewUrl));
      }
    }
    if (videos.isEmpty && images.isEmpty) {
      throw const ProviderException('SnapAny 未返回可用资源');
    }
    return ParseResult(
      type: images.isNotEmpty && videos.isEmpty ? 'gallery' : 'video',
      title: safeString(payload['text']),
      cover: cover,
      videos: videos,
      images: images,
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
