part of '../providers.dart';

class SpapiProvider extends _JsonProvider {
  const SpapiProvider();

  static const _apiBase = 'https://api.spapi.cn';
  static const _siteUrl = 'https://spapi.cn';
  static const _defaultD = 'analyze';
  static const _defaultAppKey = '0SX1mOg9';
  static const _defaultAesKey = 'kfapicn';

  @override
  VideoParseProvider get provider => VideoParseProvider.spapi;

  @override
  String get displayName => 'SPAPI';

  @override
  int get priority => 3;

  @override
  String get baseUrl => _apiBase;

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    var appKeyCookie = '';
    try {
      final home = await client.get<Object?>(
        '$_siteUrl/',
        options: Options(headers: browserHeaders()),
      );
      appKeyCookie = _extractAppKey(home.headers);
    } catch (_) {
      appKeyCookie = '';
    }

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        final request = _buildRequest(url, appKeyCookie);
        final response = await client.post<String>(
          request.endpoint,
          data: request.body,
          options: Options(
            responseType: ResponseType.plain,
            headers: browserHeaders(
              contentType: 'text/plain;charset=UTF-8',
              origin: _siteUrl,
              referer: '$_siteUrl/',
            ),
          ),
        );
        final latestCookie = _extractAppKey(response.headers);
        if (latestCookie.isNotEmpty) {
          appKeyCookie = latestCookie;
        }
        final plain = CryptoHelpers.opensslAesDecrypt(
          response.data ?? '',
          request.aesKey,
        );
        final data = ParseUtils.mapValue(plain);
        if (data['code'].toString() == '401') {
          lastError = '401 handshake';
          continue;
        }
        final status = data['status'];
        if (status != null && status.toString() != '101') {
          lastError = 'SPAPI error status=$status: ${data['msg'] ?? ''}';
          continue;
        }
        return _normalize(data, url);
      } catch (error) {
        lastError = error;
      }
    }
    throw ProviderException('SPAPI 3 次重试均失败: $lastError');
  }

  ({String endpoint, String body, String aesKey}) _buildRequest(
    String url,
    String appKeyCookie,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final aesKey = appKeyCookie.trim().isEmpty
        ? _defaultAesKey
        : appKeyCookie.trim();
    final body = CryptoHelpers.opensslAesEncrypt(url, aesKey);
    final sign = ParseUtils.md5Hex(
      '${_defaultD}0x${timestamp.toRadixString(16)}$_defaultAppKey',
    );
    return (
      endpoint: '$_apiBase/api/html?d=$_defaultD&t=$timestamp&s=$sign',
      body: body,
      aesKey: aesKey,
    );
  }

  String _extractAppKey(Headers headers) {
    final cookies = headers.map.entries
        .where((entry) => entry.key.toLowerCase() == 'set-cookie')
        .expand((entry) => entry.value);
    for (final value in cookies) {
      final match = RegExp(r'KFAPI_APPKEY=([^;]*)').firstMatch(value);
      if (match != null) {
        return match.group(1) ?? '';
      }
    }
    return '';
  }

  ParseResult _normalize(Map<String, Object?> data, String sourceUrl) {
    final inner = ParseUtils.mapValue(data['data']);
    final media = normalizeMediaResources([
      inner['video'] ?? inner['video_url'] ?? inner['url'],
      inner['images'] ?? inner['image_list'] ?? inner['pics'],
    ]);
    return ParseResult(
      type: media.images.isNotEmpty && media.videos.isEmpty
          ? 'gallery'
          : 'video',
      title: safeString(inner['title'] ?? inner['desc'] ?? data['title']),
      author: safeString(
        inner['author'] ?? inner['nickname'] ?? data['author'],
      ),
      cover: safeString(inner['image'] ?? inner['cover'] ?? inner['cover_url']),
      duration: safeString(inner['duration']),
      videos: media.videos,
      images: media.images,
      music: normalizeMusic(inner),
      platform: safeString(inner['platform']),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
