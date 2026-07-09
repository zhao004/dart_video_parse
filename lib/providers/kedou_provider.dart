part of '../providers.dart';

class KedouProvider extends _JsonProvider {
  const KedouProvider();

  static const _baseUrl = 'https://www.kedou.life';
  static const _ivBase64 = 'a2Vkb3VAODk4OSE2MzIzMw==';

  @override
  VideoParseProvider get provider => VideoParseProvider.kedou;

  @override
  String get displayName => 'Kedou';

  @override
  int get priority => 4;

  @override
  String get baseUrl => _baseUrl;

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final headers = browserHeaders(
      origin: _baseUrl,
      referer: '$_baseUrl/',
      extra: {'KdSystem': 'Kedou'},
    );
    final keysResponse = await client.get<Object?>(
      '$_baseUrl/api/auth/keys',
      options: Options(headers: headers),
    );
    final keyData = ParseUtils.mapValue(
      ParseUtils.mapValue(keysResponse.data)['data'],
    );
    final k1 = safeString(keyData['k1']);
    final k2 = safeString(keyData['k2']);
    if (k1.isEmpty || k2.isEmpty) {
      throw const ProviderException('Kedou 获取密钥失败: k1/k2 为空');
    }
    final pem = _wrapPemPublicKey(k1);
    final aesKey = CryptoHelpers.rsaPublicDecryptBase64(k2, pem);
    final aesCipher = CryptoHelpers.aesCbcPkcs7EncryptBase64(
      jsonEncode({'url': url}),
      aesKey,
      base64Decode(_ivBase64),
    );
    final body = CryptoHelpers.rsaPublicEncryptLongBase64(aesCipher, pem);
    final response = await client.post<Object?>(
      '$_baseUrl/api/video/extract/v2',
      data: body,
      options: Options(
        headers: {...headers, 'Content-Type': 'application/json'},
      ),
    );
    final payload = asMap(response.data, 'Kedou 返回空数据');
    final outer = ParseUtils.mapValue(payload['data']);
    final resultData = outer.isEmpty
        ? payload
        : ParseUtils.mapValue(outer['data'] ?? outer);
    final outerCode = outer['code'];
    if (outerCode != null && outerCode.toString() != '200') {
      throw ProviderException(
        'Kedou 返回错误 code=$outerCode: ${outer['msg'] ?? ''}',
      );
    }
    return _normalize(resultData, url);
  }

  String _wrapPemPublicKey(String raw) {
    if (raw.contains('BEGIN PUBLIC KEY')) {
      return raw;
    }
    final chunks = <String>[];
    for (var i = 0; i < raw.length; i += 64) {
      chunks.add(raw.substring(i, min(i + 64, raw.length)));
    }
    return '-----BEGIN PUBLIC KEY-----\n${chunks.join('\n')}\n-----END PUBLIC KEY-----';
  }

  ParseResult _normalize(Map<String, Object?> data, String sourceUrl) {
    final videos = <VideoItem>[];
    final images = <ImageItem>[];
    var cover = '';
    for (final item in ParseUtils.listValue(data['videoItemVoList'])) {
      final map = ParseUtils.mapValue(item);
      final baseUrl = safeString(map['baseUrl']);
      if (!ParseUtils.isHttpUrl(baseUrl)) {
        continue;
      }
      final fileType = safeString(map['fileType']).toLowerCase();
      if (ParseUtils.isImageUrl(baseUrl) ||
          (fileType == 'image' && !ParseUtils.isVideoUrl(baseUrl))) {
        images.add(ImageItem(url: baseUrl));
        cover = cover.isEmpty ? baseUrl : cover;
      } else if (ParseUtils.isVideoUrl(baseUrl) ||
          (fileType == 'video' && !ParseUtils.isImageUrl(baseUrl))) {
        videos.add(
          VideoItem(
            url: baseUrl,
            quality: safeString(map['quality'], defaultValue: '原画'),
          ),
        );
      }
    }
    if (images.isEmpty) {
      images.addAll(
        normalizeImages(data['images'] ?? data['image_list'] ?? data['pics']),
      );
    }
    final fallbackVideo = safeString(
      data['video_url'] ?? data['video'] ?? data['url'],
    );
    if (videos.isEmpty && ParseUtils.isVideoUrl(fallbackVideo)) {
      videos.add(VideoItem(url: fallbackVideo, quality: '原画'));
    }
    return ParseResult(
      type: images.isNotEmpty && videos.isEmpty ? 'gallery' : 'video',
      title: safeString(data['displayTitle'] ?? data['title'] ?? data['desc']),
      author: safeString(
        data['author'] ?? data['nickname'] ?? data['hostAlias'] ?? data['host'],
      ),
      cover: safeString(
        cover.isNotEmpty
            ? cover
            : data['cover'] ?? data['cover_url'] ?? data['image'],
      ),
      duration: safeString(data['duration']),
      videos: videos,
      images: images,
      music: normalizeMusic(data),
      platform: safeString(data['platform']),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
