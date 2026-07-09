part of '../providers.dart';

abstract class CobaltProvider extends _JsonProvider {
  const CobaltProvider();

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    final normalizedUrl = safeString(url);
    final response = await client.post<Object?>(
      '$baseUrl/',
      data: {
        'url': normalizedUrl,
        'downloadMode': 'auto',
        'filenameStyle': 'basic',
        'alwaysProxy': false,
        'disableMetadata': false,
      },
      options: Options(
        headers: browserHeaders(
          accept: 'application/json',
          contentType: 'application/json',
          origin: baseUrl,
          referer: '$baseUrl/',
        ),
      ),
    );
    final payload = asMap(response.data, '$displayName 返回空数据');
    final status = safeString(payload['status']);
    if (status == 'error') {
      final error = ParseUtils.mapValue(payload['error']);
      throw ProviderException(
        '$displayName 解析失败: ${safeString(error['code'], defaultValue: 'unknown')}',
      );
    }
    if (status == 'tunnel' || status == 'redirect') {
      return _normalizeSingle(payload, normalizedUrl);
    }
    if (status == 'picker') {
      return _normalizePicker(payload, normalizedUrl);
    }
    if (status == 'local-processing') {
      return _normalizeLocalProcessing(payload, normalizedUrl);
    }
    throw ProviderException('$displayName 返回了未知状态: $status');
  }

  ParseResult _normalizeSingle(Map<String, Object?> payload, String sourceUrl) {
    final directUrl = safeString(payload['url']);
    if (directUrl.isEmpty) {
      throw ProviderException('$displayName 未返回可下载链接');
    }
    final filename = safeString(payload['filename']);
    final mimeType = safeString(payload['type']);
    final isAudio =
        mimeType.startsWith('audio/') ||
        filename.toLowerCase().endsWith('.mp3');
    final media = normalizeMediaResources([
      {
        'url': directUrl,
        'type': mimeType.isEmpty ? filename : mimeType,
        'quality': '原画',
      },
    ]);
    return ParseResult(
      type: media.images.isNotEmpty && media.videos.isEmpty
          ? 'gallery'
          : 'video',
      title: filename,
      cover: media.images.isEmpty ? '' : media.images.first.url,
      videos: isAudio ? const [] : media.videos,
      images: isAudio ? const [] : media.images,
      music: isAudio ? MusicInfo(title: filename, url: directUrl) : null,
      platform: safeString(payload['service'], defaultValue: 'cobalt'),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }

  ParseResult _normalizePicker(Map<String, Object?> payload, String sourceUrl) {
    final media = _MediaResources();
    for (final item in ParseUtils.listValue(payload['picker'])) {
      final map = ParseUtils.mapValue(item);
      media.add({
        'url': map['url'],
        'type': map['type'],
        'quality': map['quality'] ?? '默认',
      }, defaultQuality: '默认');
    }
    if (media.isEmpty) {
      throw ProviderException('$displayName picker 场景未返回有效资源');
    }
    final audioUrl = safeString(payload['audio']);
    return ParseResult(
      type: media.images.isNotEmpty && media.videos.isEmpty
          ? 'gallery'
          : 'video',
      cover: media.images.isEmpty ? '' : media.images.first.url,
      videos: media.videos,
      images: media.images,
      music: audioUrl.isEmpty
          ? null
          : MusicInfo(
              title: safeString(
                payload['audioFilename'],
                defaultValue: 'background-audio',
              ),
              url: audioUrl,
            ),
      platform: safeString(payload['service'], defaultValue: 'cobalt'),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }

  ParseResult _normalizeLocalProcessing(
    Map<String, Object?> payload,
    String sourceUrl,
  ) {
    final tunnels = ParseUtils.listValue(payload['tunnel']);
    final directUrl = tunnels.isEmpty ? '' : safeString(tunnels.first);
    if (directUrl.isEmpty) {
      throw ProviderException('$displayName local-processing tunnel 为空');
    }
    final output = ParseUtils.mapValue(payload['output']);
    final filename = safeString(output['filename']);
    final isAudio = safeString(output['type']).startsWith('audio/');
    final media = normalizeMediaResources([
      {
        'url': directUrl,
        'type': safeString(output['type']).isEmpty
            ? filename
            : safeString(output['type']),
        'quality': '原画',
      },
    ]);
    return ParseResult(
      type: media.images.isNotEmpty && media.videos.isEmpty
          ? 'gallery'
          : 'video',
      title: filename,
      cover: media.images.isEmpty ? '' : media.images.first.url,
      videos: isAudio ? const [] : media.videos,
      images: isAudio ? const [] : media.images,
      music: isAudio ? MusicInfo(title: filename, url: directUrl) : null,
      platform: safeString(payload['service'], defaultValue: 'cobalt'),
      sourceUrl: sourceUrl,
      parserUsed: name,
    );
  }
}
