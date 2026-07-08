/// 视频资源条目。
class VideoItem {
  const VideoItem({required this.url, this.quality = ''});

  /// 视频直链。
  final String url;

  /// 清晰度或资源说明。
  final String quality;

  Map<String, Object?> toJson() => {'url': url, 'quality': quality};
}

/// 图片资源条目。
class ImageItem {
  const ImageItem({required this.url});

  /// 图片直链。
  final String url;

  Map<String, Object?> toJson() => {'url': url};
}

/// 背景音乐信息。
class MusicInfo {
  const MusicInfo({this.title = '', this.url = ''});

  /// 音乐标题。
  final String title;

  /// 音乐直链。
  final String url;

  Map<String, Object?> toJson() => {'title': title, 'url': url};
}
