part of '../providers.dart';

class GljlwProvider extends BaseVideoProvider {
  const GljlwProvider();

  static const _baseUrl = 'https://3g.gljlw.com';
  static const _homeUrl = '$_baseUrl/diy/';

  @override
  VideoParseProvider get provider => VideoParseProvider.gljlw;

  @override
  String get displayName => 'GLJLW';

  @override
  int get priority => 6;

  @override
  String get baseUrl => _baseUrl;

  @override
  String get probeUrl => _homeUrl;

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final normalizedUrl = ParseUtils.firstHttpUrl(url);
    final nonce = Random().nextDouble().toString().replaceFirst('0.', '');
    final sign = ParseUtils.md5Hex('$normalizedUrl@&^$nonce');
    final endpoint =
        '/diy/juhe.php?${ParseUtils.formEncode({'jlwzcn': '666666', 'time': '1777000661', 'key': 'c72f77c9d664c9028a7c337cfd961a45', 'url': normalizedUrl, 'r': nonce, 's': sign})}';
    final response = await client.get<String>(
      '$_baseUrl$endpoint',
      options: Options(
        responseType: ResponseType.plain,
        headers: browserHeaders(
          accept:
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          referer: _homeUrl,
        ),
      ),
    );
    return _normalizeHtml(response.data ?? '', normalizedUrl);
  }

  ParseResult _normalizeHtml(String html, String sourceUrl) {
    if (html.trim().isEmpty) {
      throw const ProviderException('GLJLW 返回了空白页面');
    }
    if (html.contains('提取次数过多') || html.contains('已被限制提取')) {
      throw const ProviderException('GLJLW 当前 IP 已被限流，请稍后重试');
    }
    final videos = <VideoItem>[];
    final images = <ImageItem>[];
    final seen = <String>{};
    for (final match in RegExp(
      '<textarea[^>]*>(.*?)</textarea>',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(html)) {
      final videoUrl = ParseUtils.cleanHtmlText(match.group(1) ?? '');
      if (!ParseUtils.isHttpUrl(videoUrl) || !seen.add(videoUrl)) {
        continue;
      }
      if (ParseUtils.isImageUrl(videoUrl)) {
        images.add(ImageItem(url: videoUrl));
      } else {
        videos.add(VideoItem(url: videoUrl, quality: '默认'));
      }
    }
    for (final match in RegExp(
      r'<a[^>]*class="btn"[^>]*href="([^"]+)"[^>]*>([^<]+)</a>',
      caseSensitive: false,
    ).allMatches(html)) {
      final href = (match.group(1) ?? '').replaceAll('&amp;', '&');
      final videoUrl = href.contains('jlwdown=')
          ? href.split('jlwdown=').last
          : href;
      if (!ParseUtils.isHttpUrl(videoUrl) || !seen.add(videoUrl)) {
        continue;
      }
      if (ParseUtils.isImageUrl(videoUrl)) {
        images.add(ImageItem(url: videoUrl));
      } else {
        videos.add(
          VideoItem(
            url: videoUrl,
            quality: ParseUtils.cleanHtmlText(match.group(2) ?? '默认'),
          ),
        );
      }
    }
    if (videos.isEmpty && images.isEmpty) {
      throw const ProviderException('GLJLW 未返回可用的视频或图集资源');
    }
    return ParseResult(
      type: images.isNotEmpty && videos.isEmpty ? 'gallery' : 'video',
      title: _extractHtmlField(html, r'标题：</strong>\s*([^<]+)'),
      author: _extractHtmlField(html, r'作者：</strong>\s*([^<]+)'),
      cover: _extractHtmlField(
        html,
        r'作品截图：</strong>\s*</p>\s*<img\s+src="([^"]+)"',
      ),
      videos: videos,
      images: images,
      platform: ParseUtils.inferPlatform(sourceUrl),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }

  String _extractHtmlField(String html, String pattern) {
    final match = RegExp(
      pattern,
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(html);
    return match == null ? '' : ParseUtils.cleanHtmlText(match.group(1) ?? '');
  }
}
