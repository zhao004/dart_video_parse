import 'media_items.dart';

/// 统一解析结果。
class ParseResult {
  const ParseResult({
    required this.type,
    this.title = '',
    this.author = '',
    this.cover = '',
    this.duration = '',
    this.videos = const <VideoItem>[],
    this.images = const <ImageItem>[],
    this.music,
    this.platform = '',
    this.sourceUrl = '',
    this.parserUsed = '',
  });

  /// 内容类型：`video` 或 `gallery`。
  final String type;

  /// 标题或描述。
  final String title;

  /// 作者昵称。
  final String author;

  /// 封面地址。
  final String cover;

  /// 视频时长。
  final String duration;

  /// 视频资源列表。
  final List<VideoItem> videos;

  /// 图集资源列表。
  final List<ImageItem> images;

  /// 背景音乐。
  final MusicInfo? music;

  /// 来源平台标识。
  final String platform;

  /// 原始输入链接。
  final String sourceUrl;

  /// 实际命中的解析源。
  final String parserUsed;

  /// 结果是否包含可消费业务数据；轮询时用它过滤空响应。
  ///
  /// 设计意图：标题、描述等元数据不能被 Flutter 播放器直接消费，
  /// 因此只有非空视频或图片资源才视为有效解析结果，避免提前截断后续轮询。
  bool get isValid =>
      videos.any((item) => item.url.trim().isNotEmpty) ||
      images.any((item) => item.url.trim().isNotEmpty);

  ParseResult copyWith({String? parserUsed}) {
    return ParseResult(
      type: type,
      title: title,
      author: author,
      cover: cover,
      duration: duration,
      videos: videos,
      images: images,
      music: music,
      platform: platform,
      sourceUrl: sourceUrl,
      parserUsed: parserUsed ?? this.parserUsed,
    );
  }

  Map<String, Object?> toJson() => {
    'type': type,
    'title': title,
    'author': author,
    'cover': cover,
    'duration': duration,
    'videos': videos.map((item) => item.toJson()).toList(),
    'images': images.map((item) => item.toJson()).toList(),
    'music': music?.toJson(),
    'platform': platform,
    'source_url': sourceUrl,
    'parser_used': parserUsed,
  };
}
