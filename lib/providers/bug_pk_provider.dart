part of '../providers.dart';

class BugPkProvider extends _JsonProvider {
  const BugPkProvider();

  @override
  VideoParseProvider get provider => VideoParseProvider.bugpk;

  @override
  String get displayName => 'BugPK';

  @override
  int get priority => 14;

  @override
  String get baseUrl => 'https://api.bugpk.com';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final normalizedUrl = safeString(url);
    final response = await client.get<Object?>(
      '$_apiUrlFor(normalizedUrl)',
      queryParameters: {'url': normalizedUrl},
      options: Options(
        headers: browserHeaders(accept: 'application/json, text/plain, */*'),
      ),
    );
    final payload = asMap(response.data, 'BK-SV 返回空数据');
    if (payload['code'].toString() != '200') {
      throw ProviderException(
        safeString(payload['message'], defaultValue: 'BK-SV 解析失败'),
      );
    }
    final data = asMap(payload['data'], 'BK-SV 返回结果结构异常');
    return _normalize(data, normalizedUrl);
  }

  String _apiUrlFor(String sourceUrl) {
    final platform = _inferPlatformKey(sourceUrl);
    return switch (platform) {
      'douyin' => '$baseUrl/api/douyin',
      'kuaishou' => '$baseUrl/api/ksjx',
      'bilibili' => '$baseUrl/api/bilibili',
      'xhs' => '$baseUrl/api/xhsjx',
      'toutiao' => '$baseUrl/api/toutiao',
      _ => '$baseUrl/api/short_videos',
    };
  }

  String _inferPlatformKey(String sourceUrl) {
    final url = sourceUrl.toLowerCase();
    if (url.contains('douyin.com')) {
      return 'douyin';
    }
    if (url.contains('kuaishou.com')) {
      return 'kuaishou';
    }
    if (url.contains('bilibili.com') || url.contains('b23.tv')) {
      return 'bilibili';
    }
    if (url.contains('xiaohongshu.com') || url.contains('xhslink')) {
      return 'xhs';
    }
    if (url.contains('toutiao.com') || url.contains('ixigua.com')) {
      return 'toutiao';
    }
    return 'all';
  }

  ParseResult _normalize(Map<String, Object?> data, String sourceUrl) {
    final type = safeString(data['type']).toLowerCase();
    final videoUrl = safeString(data['url']);
    final videos = <VideoItem>[
      if (videoUrl.isNotEmpty)
        VideoItem(
          url: videoUrl,
          quality: safeString(data['quality'], defaultValue: '原画'),
        ),
    ];
    for (final item in ParseUtils.listValue(data['video_backup'])) {
      final map = ParseUtils.mapValue(item);
      final backupUrl = safeString(map['url']);
      if (backupUrl.isNotEmpty) {
        videos.add(
          VideoItem(
            url: backupUrl,
            quality: safeString(map['quality'], defaultValue: '备用'),
          ),
        );
      }
    }
    final images = normalizeImages(data['images'] ?? data['urls']);
    if (videos.isEmpty && images.isEmpty) {
      throw const ProviderException('BK-SV 未返回可用资源');
    }
    final cover = safeString(
      data['cover'] ?? data['coverUrl'],
      defaultValue: images.isEmpty ? '' : images.first.url,
    );
    return ParseResult(
      type:
          {'img', 'image', 'images', 'normal'}.contains(type) ||
              (images.isNotEmpty && videos.isEmpty)
          ? 'gallery'
          : 'video',
      title: safeString(data['title'] ?? data['desc']),
      author: _extractAuthor(data['author']),
      cover: cover,
      duration: safeString(data['time']),
      videos: videos,
      images: images,
      music: normalizeMusic(data),
      platform: ParseUtils.inferPlatform(sourceUrl),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }

  String _extractAuthor(Object? author) {
    if (author is Map) {
      return safeString(
        author['name'] ?? author['nickname'] ?? author['user_name'],
      );
    }
    return safeString(author);
  }
}
