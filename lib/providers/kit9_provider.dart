part of '../providers.dart';

class Kit9Provider extends _JsonProvider {
  const Kit9Provider();

  @override
  VideoParseProvider get provider => VideoParseProvider.kit9;

  @override
  String get displayName => 'Kit9';

  @override
  int get priority => 8;

  @override
  String get baseUrl => 'https://apis.kit9.cn';

  @override
  String get probeUrl => '$baseUrl/api/aggregate_videos/';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final normalizedUrl = safeString(url);
    final response = await client.get<Object?>(
      '$baseUrl/api/aggregate_videos/api.php',
      queryParameters: {'link': normalizedUrl},
      options: Options(
        headers: browserHeaders(
          accept: 'application/json, text/plain, */*',
          referer: probeUrl,
        ),
      ),
    );
    final payload = asMap(response.data, 'Kit9 返回空数据');
    if (payload['code'].toString() != '200') {
      throw ProviderException(
        safeString(payload['msg'], defaultValue: 'Kit9 解析失败'),
      );
    }
    var rawData = payload['data'];
    if (rawData is List) {
      rawData = rawData.isEmpty ? <String, Object?>{} : rawData.first;
    }
    final data = asMap(rawData, 'Kit9 返回结果结构异常');
    final videoUrl = safeString(
      data['video_link'] ?? data['video_url'] ?? data['url'],
    );
    if (videoUrl.isEmpty) {
      throw const ProviderException('Kit9 未返回视频直链');
    }
    final author = ParseUtils.mapValue(data['author']);
    return ParseResult(
      type: 'video',
      title: safeString(
        data['video_title'] ?? data['video_desc'] ?? data['title'],
      ),
      author: safeString(author['name']),
      cover: safeString(
        data['video_cover'] ?? data['cover'] ?? author['avatar'],
      ),
      duration: safeString(data['video_time'] ?? data['duration']),
      videos: [VideoItem(url: videoUrl, quality: '原画')],
      music: normalizeMusic(data),
      platform: safeString(payload['parsing_type'] ?? payload['type']),
      sourceUrl: normalizedUrl,
      parserUsed: name,
    );
  }
}
