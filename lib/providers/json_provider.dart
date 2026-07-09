part of '../providers.dart';

abstract class _JsonProvider extends BaseVideoProvider {
  const _JsonProvider();

  Map<String, Object?> asMap(Object? value, String errorMessage) {
    final data = ParseUtils.mapValue(value);
    if (data.isEmpty) {
      throw ProviderException(errorMessage);
    }
    return data;
  }

  List<ImageItem> normalizeImages(Object? rawImages) {
    final media = _MediaResources();
    for (final item in ParseUtils.listValue(rawImages)) {
      media.add(item, fallbackKind: 'image');
    }
    return media.images;
  }

  /// 将不同源站返回的资源结构统一拆分成视频和图集图片。
  ///
  /// 设计意图：上游 `type` 字段经常不可靠，必须同时结合 URL 特征、
  /// MIME/扩展名和调用方兜底类型，避免图片被误放进视频列表。
  _MediaResources normalizeMediaResources(
    Iterable<Object?> resources, {
    String defaultQuality = '原画',
    String fallbackKind = 'video',
  }) {
    final media = _MediaResources();
    for (final resource in resources) {
      media.add(
        resource,
        defaultQuality: defaultQuality,
        fallbackKind: fallbackKind,
      );
    }
    return media;
  }

  MusicInfo? normalizeMusic(Map<String, Object?> data) {
    final musicRaw = data['music'];
    if (musicRaw is Map) {
      final url = safeString(musicRaw['url']);
      final title = safeString(musicRaw['title'], defaultValue: '背景音乐');
      return url.isEmpty && title.isEmpty
          ? null
          : MusicInfo(title: title, url: url);
    }
    final title = safeString(
      data['music_title'] ?? data['musicTitle'] ?? data['music_name'],
    );
    final url = safeString(data['music_url'] ?? data['musicUrl']);
    return title.isEmpty && url.isEmpty
        ? null
        : MusicInfo(title: title, url: url);
  }
}

class _MediaResources {
  final videos = <VideoItem>[];
  final images = <ImageItem>[];
  final _seen = <String>{};

  void add(
    Object? resource, {
    String defaultQuality = '原画',
    String fallbackKind = 'video',
  }) {
    if (resource == null) {
      return;
    }
    if (resource is List) {
      for (final item in resource) {
        add(item, defaultQuality: defaultQuality, fallbackKind: fallbackKind);
      }
      return;
    }
    final map = ParseUtils.mapValue(resource);
    final rawUrl = map.isEmpty
        ? ParseUtils.stringValue(resource)
        : ParseUtils.stringValue(
            map['url'] ??
                map['baseUrl'] ??
                map['video_url'] ??
                map['videoUrl'] ??
                map['resource_url'] ??
                map['preview_url'] ??
                map['download_url'] ??
                map['downloadUrl'] ??
                map['play_url'] ??
                map['playUrl'] ??
                map['nwm_video_url'] ??
                map['src'] ??
                map['href'] ??
                map['link'],
          );
    if (!ParseUtils.isHttpUrl(rawUrl) || !_seen.add(rawUrl)) {
      return;
    }
    final rawType = map.isEmpty
        ? fallbackKind
        : ParseUtils.stringValue(
            map['type'] ??
                map['fileType'] ??
                map['file_type'] ??
                map['media_type'] ??
                map['mediaType'] ??
                map['kind'] ??
                map['resource_type'] ??
                map['mime_type'] ??
                map['mimeType'] ??
                map['ext'] ??
                fallbackKind,
          ).toLowerCase();
    if (_isImageResource(rawUrl, rawType, fallbackKind)) {
      images.add(ImageItem(url: rawUrl));
      return;
    }
    if (_isVideoResource(rawUrl, rawType, fallbackKind)) {
      videos.add(
        VideoItem(
          url: rawUrl,
          quality: ParseUtils.stringValue(
            map['quality'] ?? map['quality_note'],
            defaultValue: defaultQuality,
          ),
        ),
      );
    }
  }

  void addVideo(String url, {String quality = '原画'}) {
    if (!ParseUtils.isHttpUrl(url) ||
        ParseUtils.isImageUrl(url) ||
        !_seen.add(url)) {
      return;
    }
    videos.add(VideoItem(url: url, quality: quality));
  }

  void addImage(String url) {
    if (!ParseUtils.isHttpUrl(url) ||
        ParseUtils.isVideoUrl(url) ||
        !_seen.add(url)) {
      return;
    }
    images.add(ImageItem(url: url));
  }

  bool get isEmpty => videos.isEmpty && images.isEmpty;

  static bool _isImageResource(
    String url,
    String rawType,
    String fallbackKind,
  ) {
    if (ParseUtils.isVideoUrl(url)) {
      return false;
    }
    return rawType == 'image' ||
        rawType == 'images' ||
        rawType == 'img' ||
        rawType == 'photo' ||
        rawType == 'photos' ||
        rawType == 'picture' ||
        rawType == 'album' ||
        rawType == 'normal' ||
        rawType.startsWith('image/') ||
        rawType.contains('image') ||
        _hasImageExtension(rawType) ||
        ParseUtils.isImageUrl(url) ||
        (fallbackKind == 'image' && !ParseUtils.isVideoUrl(url));
  }

  static bool _isVideoResource(
    String url,
    String rawType,
    String fallbackKind,
  ) {
    if (ParseUtils.isImageUrl(url)) {
      return false;
    }
    return rawType == 'video' ||
        rawType == 'videos' ||
        rawType == 'movie' ||
        rawType == 'mp4' ||
        rawType == 'm3u8' ||
        rawType.startsWith('video/') ||
        rawType.contains('video') ||
        _hasVideoExtension(rawType) ||
        ParseUtils.isVideoUrl(url) ||
        (fallbackKind == 'video' && !ParseUtils.isImageUrl(url));
  }

  static bool _hasImageExtension(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic');
  }

  static bool _hasVideoExtension(String value) {
    final lower = value.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m3u8') ||
        lower.endsWith('.webm');
  }
}
