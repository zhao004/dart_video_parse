part of '../providers.dart';

class Tool33Provider extends _JsonProvider {
  const Tool33Provider();

  static const _siteUrl = 'https://33tool.com';
  static const _apiBaseUrl = 'https://api.33tool.com';
  static const _appKey = 'MyXtNUmF';
  static const _appSecret = 'TVlzc5bm';
  static const _appVersion = '1.0.0';

  @override
  VideoParseProvider get provider => VideoParseProvider.tool33;

  @override
  String get displayName => '33tool';

  @override
  int get priority => 7;

  @override
  String get baseUrl => _siteUrl;

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final normalizedUrl = ParseUtils.firstHttpUrl(url);
    final rule = _resolveRule(normalizedUrl);
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = Random().nextInt(1 << 32).toRadixString(36);
    final signPayload = {
      'AppKey': _appKey,
      'AppVersion': _appVersion,
      'Nonce': nonce,
      'Timestamp': '$timestamp',
    };
    final plainText =
        (signPayload.keys.toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())))
            .map((key) => '$key${signPayload[key]}')
            .join() +
        _appSecret;
    final apiUrl =
        '$_apiBaseUrl${rule.path}?${ParseUtils.formEncode({'url': normalizedUrl})}';
    final response = await client.get<Object?>(
      apiUrl,
      options: Options(
        headers: browserHeaders(
          accept: 'application/json, text/plain, */*',
          origin: _siteUrl,
          referer: '$_siteUrl/video_parse/',
          extra: {
            'Timestamp': '$timestamp',
            'Nonce': nonce,
            'App-Version': _appVersion,
            'Sign': ParseUtils.md5HexUpper(plainText),
          },
        ),
      ),
    );
    final payload = asMap(response.data, '33tool 返回空数据');
    if (payload['code'].toString() == '-1') {
      throw ProviderException(
        safeString(payload['msg'], defaultValue: '33tool 无法解析该链接'),
      );
    }
    final rawResult = ParseUtils.mapValue(payload['data'] ?? payload);
    return _normalize(rawResult, normalizedUrl, rule.platform);
  }

  ({String platform, String path}) _resolveRule(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('douyin.com')) {
      return (platform: 'douyin', path: '/api/parse/douyin');
    }
    if (lower.contains('bilibili.com') || lower.contains('b23.tv')) {
      return (platform: 'bilibili', path: '/api/parse/bilibili');
    }
    if (lower.contains('xiaohongshu.com') || lower.contains('xhslink.com')) {
      return (platform: 'redbook', path: '/api/parse/redbook');
    }
    if (lower.contains('kuaishou.com')) {
      return (platform: 'kuaishou', path: '/api/parse/kuaishou');
    }
    throw const ProviderException('33tool 不支持该平台链接');
  }

  ParseResult _normalize(
    Map<String, Object?> data,
    String sourceUrl,
    String platform,
  ) {
    final media = normalizeMediaResources([
      data['videoUrl'] ?? data['video_url'] ?? data['video'] ?? data['url'],
      data['backupUrl'] ?? data['backup_url'],
      data['images'] ?? data['imageList'] ?? data['pics'],
    ]);
    if (media.isEmpty) {
      throw const ProviderException('33tool 未返回可用视频或图集资源');
    }
    return ParseResult(
      type: media.images.isNotEmpty && media.videos.isEmpty
          ? 'gallery'
          : 'video',
      title: safeString(data['title'] ?? data['desc'] ?? data['description']),
      author: safeString(
        data['author'] ?? data['nickname'] ?? data['authorName'],
      ),
      cover: safeString(data['coverUrl'] ?? data['cover'] ?? data['image']),
      duration: safeString(data['duration']),
      videos: media.videos,
      images: media.images,
      music: normalizeMusic(data),
      platform: safeString(data['platform'], defaultValue: platform),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
