part of '../providers.dart';

class NologoProvider extends _JsonProvider {
  const NologoProvider();

  @override
  VideoParseProvider get provider => VideoParseProvider.nologo;

  @override
  String get displayName => 'Nologo';

  @override
  int get priority => 13;

  @override
  String get baseUrl => 'https://nologo.code24.top';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final response = await client.get<Object?>(
      '$baseUrl/api/download/verify',
      queryParameters: {'url': url},
      options: Options(
        headers: browserHeaders(
          accept: 'application/json, text/plain, */*',
          referer: '$baseUrl/',
        ),
      ),
    );
    final payload = asMap(response.data, '去水印下载鸭返回空数据');
    if (payload['code'].toString() != '200') {
      throw ProviderException(
        safeString(payload['message'], defaultValue: '去水印下载鸭解析失败'),
      );
    }
    final data = asMap(payload['data'], '去水印下载鸭返回结果结构异常');
    return _normalize(data, url);
  }

  ParseResult _normalize(Map<String, Object?> data, String sourceUrl) {
    final type = safeString(data['type']).toLowerCase();
    final title = safeString(data['title'] ?? data['desc']);
    if (type == 'video') {
      final videoUrl = safeString(
        data['url'] ?? data['videoUrl'] ?? data['video_url'],
      );
      if (videoUrl.isEmpty) {
        throw const ProviderException('去水印下载鸭未返回视频直链');
      }
      return ParseResult(
        type: 'video',
        title: title,
        videos: [VideoItem(url: videoUrl, quality: '原画')],
        sourceUrl: sourceUrl,
        parserUsed: name,
      );
    }
    final images = normalizeImages(data['urls'] ?? data['pics']);
    if (images.isEmpty) {
      throw const ProviderException('去水印下载鸭未返回图集资源');
    }
    return ParseResult(
      type: 'gallery',
      title: title,
      cover: images.first.url,
      images: images,
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
