part of '../providers.dart';

class KukuToolProvider extends _JsonProvider {
  const KukuToolProvider();

  static const _pagePath = '/en';
  static const _responseAesKey = '12345678901234567890123456789013';
  static const _authRoute = 'auth-25e532';
  static const _keyField = 'k_25e532';
  static const _seedField = 's_25e532';
  static const _payloadField = 'p_25e532';
  static const _ivField = 'i_25e532';
  static const _versionField = 'r_25e532';

  @override
  VideoParseProvider get provider => VideoParseProvider.kukutool;

  @override
  String get displayName => 'KuKuTool';

  @override
  int get priority => 16;

  @override
  String get baseUrl => 'https://dy.kukutool.com';

  @override
  String get probeUrl => '$baseUrl$_pagePath';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final rawParams = {
      'requestURL': url,
      'captchaKey': '',
      'captchaInput': '',
      'totalSuccessCount': '0',
      'successCount': '0',
      'firstSuccessDate': '',
      'pagePath': _pagePath,
      'uwx_id': '',
      'isMobile': 'false',
      'geoipIp': '',
    };
    final headers = browserHeaders(
      accept: 'application/json, text/plain, */*',
      contentType: 'application/json',
      origin: baseUrl,
      referer: '$baseUrl$_pagePath',
    );
    final authResponse = await client.post<Object?>(
      '$baseUrl/api/$_authRoute',
      data: {'requestURL': url, 'pagePath': _pagePath, 'mode': 'single'},
      options: Options(headers: headers),
    );
    final authPayload = asMap(authResponse.data, 'KuKuTool 鉴权响应结构异常');
    final authKey = safeString(authPayload[_keyField]);
    final authSeed = safeString(authPayload[_seedField]);
    if (authKey.isEmpty || authSeed.isEmpty) {
      throw const ProviderException('KuKuTool 鉴权响应结构异常');
    }
    final key = CryptoHelpers.sha256Bytes('$authKey:$authSeed');
    final encrypted = CryptoHelpers.aesGcmEncryptJson(
      jsonEncode(rawParams),
      key,
    );
    final parseResponse = await client.post<Object?>(
      '$baseUrl/api/parse',
      data: {
        'version': 3,
        _keyField: authKey,
        _payloadField: encrypted.payloadBase64,
        _ivField: encrypted.ivBase64,
        _versionField: 1,
      },
      options: Options(headers: headers),
    );
    final payload = asMap(parseResponse.data, 'KuKuTool 返回空数据');
    if (payload['status'].toString() != '0') {
      throw ProviderException(
        safeString(
          payload['message'] ?? payload['error'],
          defaultValue: 'KuKuTool 解析失败',
        ),
      );
    }
    Object? data = payload['data'];
    if (payload['encrypt'] == true) {
      data = _decryptResponsePayload(
        safeString(payload['data']),
        safeString(payload['iv']),
      );
    }
    return _normalize(asMap(data, 'KuKuTool 返回结果结构异常'), url);
  }

  Map<String, Object?> _decryptResponsePayload(String data, String iv) {
    String decodeCustom(String value) {
      const standard =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
      const custom =
          'ZYXABCDEFGHIJKLMNOPQRSTUVWzyxabcdefghijklmnopqrstuvw9876543210-_';
      return value.split('').map((char) {
        final index = custom.indexOf(char);
        return index == -1 ? char : standard[index];
      }).join();
    }

    String blockReverse(String value) {
      final buffer = StringBuffer();
      for (var i = 0; i < value.length; i += 8) {
        buffer.write(
          value
              .substring(i, min(i + 8, value.length))
              .split('')
              .reversed
              .join(),
        );
      }
      return buffer.toString();
    }

    String xor(String value) =>
        String.fromCharCodes(value.codeUnits.map((unit) => unit ^ 0x5a));
    final decodedData = decodeCustom(blockReverse(xor(data)));
    final decodedIv = decodeCustom(blockReverse(xor(iv)));
    final plain = CryptoHelpers.aesCbcPkcs7DecryptBase64(
      decodedData,
      _responseAesKey,
      decodedIv,
    );
    return ParseUtils.mapValue(plain);
  }

  ParseResult _normalize(Map<String, Object?> data, String sourceUrl) {
    final type = safeString(data['type']).toLowerCase();
    final title = safeString(data['title'] ?? data['desc']);
    final videoUrl = safeString(data['url']);
    final videos = <VideoItem>[
      if (videoUrl.isNotEmpty) VideoItem(url: videoUrl, quality: '原画'),
    ];
    final images = normalizeImages(data['pics']);
    if (type == 'video') {
      if (videos.isEmpty) {
        throw const ProviderException('KuKuTool 未返回视频直链');
      }
      return ParseResult(
        type: 'video',
        title: title,
        cover: safeString(data['cover']),
        videos: videos,
        sourceUrl: sourceUrl,
        parserUsed: name,
      );
    }
    if (images.isEmpty) {
      throw const ProviderException('KuKuTool 未返回图集资源');
    }
    return ParseResult(
      type: 'gallery',
      title: title,
      cover: safeString(data['cover'], defaultValue: images.first.url),
      images: images,
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
