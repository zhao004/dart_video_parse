part of '../providers.dart';

class ParseVideoProvider extends _JsonProvider {
  const ParseVideoProvider();

  static const _baseUrl = 'https://www.parsevideo.com';
  static const _apiPath = '/parsevideo/enc.html';
  static const _hashSalt = '%8vcf';
  static const _aesKeyText = 'd41d8cd98f00b204e9800998ecf8427e';

  @override
  VideoParseProvider get provider => VideoParseProvider.parsevideo;

  @override
  String get displayName => 'ParseVideo';

  @override
  int get priority => 2;

  @override
  String get baseUrl => _baseUrl;

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final normalizedUrl = ParseUtils.firstHttpUrl(url);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = ParseUtils.md5Hex('$normalizedUrl$_hashSalt$timestamp');
    final plainForm = ParseUtils.formEncode({
      'url': normalizedUrl,
      'proxyip': 'on',
    });
    final encryptedData = CryptoHelpers.aesEcbPkcs7EncryptToHex(
      plainForm,
      _aesKeyText,
    );
    final response = await client.post<Object?>(
      '$_baseUrl$_apiPath?hash=$hash&timestamp=$timestamp',
      data: ParseUtils.formEncode({'data': encryptedData}),
      options: Options(
        headers: browserHeaders(
          contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
          origin: _baseUrl,
          referer: '$_baseUrl/',
          extra: {'X-Requested-With': 'XMLHttpRequest'},
        ),
      ),
    );
    final payload = asMap(response.data, 'ParseVideo 返回空数据');
    if (payload['code'].toString() == '0') {
      throw const ProviderException('ParseVideo 可能需要有效 Cookie');
    }
    if (payload['code'].toString() != '1') {
      throw ProviderException(
        'ParseVideo 返回异常 code=${payload['code']}: ${payload['msg'] ?? ''}',
      );
    }
    final encryptedResponse = safeString(payload['data']);
    if (encryptedResponse.isEmpty) {
      throw const ProviderException('ParseVideo 返回空加密数据');
    }
    final plainText = CryptoHelpers.aesEcbPkcs7DecryptHex(
      encryptedResponse,
      _aesKeyText,
    );
    return _normalize(ParseUtils.mapValue(plainText), normalizedUrl);
  }

  ParseResult _normalize(Map<String, Object?> data, String sourceUrl) {
    final media = normalizeMediaResources([
      data['video_url'] ?? data['video'] ?? data['url'],
      data['backup_url'],
      data['images'] ?? data['image_list'] ?? data['pics'],
    ]);
    final isGallery = media.images.isNotEmpty && media.videos.isEmpty;
    return ParseResult(
      type: isGallery ? 'gallery' : 'video',
      title: safeString(data['title'] ?? data['desc']),
      author: safeString(data['author'] ?? data['nickname']),
      cover: safeString(data['cover'] ?? data['cover_url'] ?? data['image']),
      duration: safeString(data['duration']),
      videos: media.videos,
      images: media.images,
      music: normalizeMusic(data),
      platform: safeString(data['platform']),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
