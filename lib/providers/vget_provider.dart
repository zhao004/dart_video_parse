part of '../providers.dart';

class VgetProvider extends BaseVideoProvider {
  const VgetProvider();

  @override
  VideoParseProvider get provider => VideoParseProvider.vget;

  @override
  String get displayName => 'VGet';

  @override
  int get priority => 17;

  @override
  String get baseUrl => 'https://vget.xyz';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final response = await client.post<String>(
      '$baseUrl/dl',
      data: ParseUtils.formEncode({'url': url}),
      options: Options(
        responseType: ResponseType.plain,
        headers: browserHeaders(
          contentType: 'application/x-www-form-urlencoded',
          origin: baseUrl,
          referer: '$baseUrl/',
        ),
      ),
    );
    return _normalizeHtml(response.data ?? '', url);
  }

  ParseResult _normalizeHtml(String html, String sourceUrl) {
    if (html.trim().isEmpty) {
      throw const ProviderException('VGet 返回空页面');
    }
    final videos = <VideoItem>[];
    final images = <ImageItem>[];
    final seen = <String>{};
    final rowPattern = RegExp(
      r'<tr>\s*<td>(.*?)</td>\s*<td>.*?</td>\s*<td>(.*?)</td>\s*<td><button[^>]*class="btn-download[^"]*"[^>]*data="([^"]+)"',
      dotAll: true,
      caseSensitive: false,
    );
    for (final match in rowPattern.allMatches(html)) {
      final label = ParseUtils.cleanHtmlText(match.group(1) ?? '');
      final ext = ParseUtils.cleanHtmlText(match.group(2) ?? '').toLowerCase();
      final fileUrl = ParseUtils.cleanHtmlText(match.group(3) ?? '');
      if (fileUrl.isEmpty || !seen.add(fileUrl)) {
        continue;
      }
      if ({'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ||
          ParseUtils.isImageUrl(fileUrl)) {
        images.add(ImageItem(url: fileUrl));
      } else if (ext != 'mhtml' && !ParseUtils.isImageUrl(fileUrl)) {
        videos.add(
          VideoItem(url: fileUrl, quality: label.isEmpty ? ext : label),
        );
      }
    }
    if (videos.isEmpty && images.isEmpty) {
      throw const ProviderException('VGet 未返回可下载资源');
    }
    return ParseResult(
      type: images.isNotEmpty && videos.isEmpty ? 'gallery' : 'video',
      title: _extractField(html, 'Title:'),
      author: _extractField(html, 'Uploader:'),
      cover: images.isEmpty ? '' : images.first.url,
      duration: _extractField(html, 'Duration:'),
      videos: videos,
      images: images,
      platform: ParseUtils.inferPlatform(sourceUrl),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }

  String _extractField(String html, String field) {
    final pattern = RegExp(
      '${RegExp.escape(field)}\\s*(.*?)\\s*(?:Uploader:|Likes:|Duration:|Upload_date:|Webpage:|Download Best Quality|\$)',
      dotAll: true,
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html);
    return match == null ? '' : ParseUtils.cleanHtmlText(match.group(1) ?? '');
  }
}
