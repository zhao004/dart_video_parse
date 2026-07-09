import 'media_items.dart';

/// 前端页面可直接使用的解析媒体类型。
///
/// 设计意图：不同解析源返回的 `type` 字段不稳定，部分源会在视频结果中
/// 同时携带图片资源。统一枚举后，前端只需要根据 [ParseResult.mediaType]
/// 或 JSON 中的 `media_type` 决定跳转视频页还是图集页。
enum ParseMediaType {
  video('video'),
  gallery('gallery'),
  unknown('unknown');

  const ParseMediaType(this.value);

  /// 对外序列化使用的稳定字符串。
  final String value;

  /// 将解析源原始类型压缩成稳定枚举。
  ///
  /// 边界策略：无法识别的类型返回 [ParseMediaType.unknown]，避免前端把
  /// 上游脏值误判成视频或图集。
  static ParseMediaType fromValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'video':
        return ParseMediaType.video;
      case 'gallery':
      case 'image':
      case 'images':
      case 'img':
      case 'photo':
      case 'photos':
      case 'album':
        return ParseMediaType.gallery;
      default:
        return ParseMediaType.unknown;
    }
  }
}

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

  /// 解析源声明的原始内容类型。
  ///
  /// 不同上游命名不完全一致，前端分流请优先使用 [mediaType]、[isVideo]
  /// 或 [isGallery]，不要直接依赖此字段。
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

  /// 是否包含可用视频资源。
  bool get hasVideos => videos.any((item) => item.url.trim().isNotEmpty);

  /// 是否包含可用图片资源。
  bool get hasImages => images.any((item) => item.url.trim().isNotEmpty);

  /// 统一后的媒体类型，是前端页面跳转的唯一推荐判断依据。
  ///
  /// 取舍说明：当视频和图片同时存在时优先视为视频结果，因为很多解析源会
  /// 把封面、缩略图或混合资源放进图片列表，直接按图片列表判断会误进图集页。
  ParseMediaType get mediaType {
    if (hasVideos) {
      return ParseMediaType.video;
    }
    if (hasImages) {
      return ParseMediaType.gallery;
    }
    return ParseMediaType.fromValue(type);
  }

  /// 统一后的媒体类型字符串。
  String get mediaTypeValue => mediaType.value;

  /// 是否应展示视频结果页。
  bool get isVideo => mediaType == ParseMediaType.video;

  /// 是否应展示图集结果页。
  bool get isGallery => mediaType == ParseMediaType.gallery;

  int get _validVideoCount =>
      videos.where((item) => item.url.trim().isNotEmpty).length;

  int get _validImageCount =>
      images.where((item) => item.url.trim().isNotEmpty).length;

  /// 结果是否包含可消费业务数据；轮询时用它过滤空响应。
  ///
  /// 设计意图：标题、描述等元数据不能被 Flutter 播放器直接消费，
  /// 因此只有非空视频或图片资源才视为有效解析结果，避免提前截断后续轮询。
  bool get isValid => hasVideos || hasImages;

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

  Map<String, Object?> toJson() {
    final resolvedType = mediaTypeValue;
    return {
      'type': resolvedType,
      'media_type': resolvedType,
      'declared_type': type.trim().toLowerCase(),
      'is_video': isVideo,
      'is_gallery': isGallery,
      'videos_count': _validVideoCount,
      'images_count': _validImageCount,
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
}
