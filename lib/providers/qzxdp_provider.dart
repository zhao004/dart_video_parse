part of '../providers.dart';

class QzxdpProvider extends _JsonProvider {
  const QzxdpProvider();

  @override
  VideoParseProvider get provider => VideoParseProvider.qzxdp;

  @override
  String get displayName => 'QZXDP';

  @override
  int get priority => 20;

  @override
  String get baseUrl => 'https://tools.qzxdp.cn';

  @override
  String get probeUrl => '$baseUrl/video_spider';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final body = ParseUtils.formEncode({
      'video_url': ParseUtils.firstHttpUrl(url),
    });
    final response = await client.post<Object?>(
      '$baseUrl/api/video_spider/query',
      data: body,
      options: Options(
        headers: browserHeaders(
          accept: 'application/json, text/plain, */*',
          contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
          origin: baseUrl,
          referer: '$baseUrl/video_spider',
          extra: {'X-Requested-With': 'XMLHttpRequest'},
        ),
      ),
    );
    final payload = asMap(response.data, 'QZXDP 返回空数据');
    if (payload['status'] == 'limit') {
      throw ProviderException('QZXDP 限流: ${payload['message'] ?? '请求过于频繁'}');
    }
    var resultData = payload['data'] ?? payload;
    if (resultData is List) {
      if (resultData.isEmpty) {
        throw const ProviderException('QZXDP 返回空数据列表（可能被限流）');
      }
      resultData = resultData.first;
    }
    return _normalize(asMap(resultData, 'QZXDP 返回结构异常'), url);
  }

  ParseResult _normalize(Map<String, Object?> data, String sourceUrl) {
    final images = normalizeImages(data['images'] ?? data['image_list']);
    final videoUrl = safeString(
      data['video_url'] ??
          data['video'] ??
          data['url'] ??
          data['nwm_video_url'],
    );
    final videos = <VideoItem>[
      if (videoUrl.isNotEmpty) VideoItem(url: videoUrl, quality: '原画'),
    ];
    final noWatermarkUrl = safeString(
      data['nwm_video_url'] ?? data['video_nwm'],
    );
    if (noWatermarkUrl.isNotEmpty && noWatermarkUrl != videoUrl) {
      videos.add(VideoItem(url: noWatermarkUrl, quality: '无水印'));
    }
    return ParseResult(
      type: images.isNotEmpty && videos.isEmpty ? 'gallery' : 'video',
      title: safeString(data['title'] ?? data['desc'] ?? data['description']),
      author: safeString(
        data['author'] ?? data['nickname'] ?? data['author_name'],
      ),
      cover: safeString(
        data['cover'] ??
            data['cover_url'] ??
            data['image'] ??
            data['thumbnail'],
      ),
      duration: safeString(data['duration']),
      videos: videos,
      images: images,
      music: normalizeMusic(data),
      platform: safeString(data['platform'] ?? data['source']),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
