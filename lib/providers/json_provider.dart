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
    final images = <ImageItem>[];
    for (final item in ParseUtils.listValue(rawImages)) {
      final imageUrl = item is Map ? safeString(item['url']) : safeString(item);
      if (imageUrl.isNotEmpty) {
        images.add(ImageItem(url: imageUrl));
      }
    }
    return images;
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
