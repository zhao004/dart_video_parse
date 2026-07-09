import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 解析源通用工具函数，集中处理 URL、JSON 和签名小逻辑。
abstract final class ParseUtils {
  /// 生成小写 MD5，用于还原多个前端签名算法。
  static String md5Hex(String value) =>
      md5.convert(utf8.encode(value)).toString();

  /// 生成大写 MD5，用于 33tool 请求签名。
  static String md5HexUpper(String value) => md5Hex(value).toUpperCase();

  /// 从任意值安全读取字符串，避免第三方返回 `null` 或复杂结构时崩溃。
  static String stringValue(Object? value, {String defaultValue = ''}) {
    if (value == null) {
      return defaultValue;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? defaultValue : normalized;
  }

  /// 将响应体解析为 Map；结构不匹配时返回空 Map，由 Provider 决定错误策略。
  ///
  /// 异常策略：纯 URL、普通文本等非 JSON 字符串不能向外抛出格式化异常，
  /// 因为解析源归一层会先尝试把动态字段当结构读取，再按字符串兜底处理。
  static Map<String, Object?> mapValue(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String && value.trim().isNotEmpty) {
      Object? decoded;
      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return <String, Object?>{};
      }
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    }
    return <String, Object?>{};
  }

  /// 将响应体解析为 List；结构不匹配时返回空 List。
  static List<Object?> listValue(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return <Object?>[];
  }

  /// 类似 JS URLSearchParams 的表单编码。
  static String formEncode(Map<String, Object?> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(stringValue(entry.value))}',
        )
        .join('&');
  }

  /// 提取分享文案中的第一个 HTTP 链接。
  static String firstHttpUrl(String text) {
    final match = RegExp(r'https?://[^\s|\u4e00-\u9fa5]+').firstMatch(text);
    if (match == null) {
      return text.trim();
    }
    return match.group(0)!.trim();
  }

  /// 判断字符串是否为可请求的 HTTP/HTTPS URL。
  static bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasScheme &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// 判断 URL 是否明显指向图片资源。
  ///
  /// 设计意图：部分解析源会把图集图片塞进视频列表，不能只相信上游
  /// `fileType` 字段。这里按路径、查询参数和常见 CDN 标识做保守判断。
  static bool isImageUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return false;
    }
    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.heic') ||
        query.contains('mime_type=image') ||
        query.contains('sc=image') ||
        query.contains('biz_tag=aweme_images') ||
        value.toLowerCase().contains('tplv-dy-aweme-images');
  }

  /// 判断 URL 是否明显指向视频资源。
  static bool isVideoUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) {
      return false;
    }
    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.webm') ||
        query.contains('mime_type=video') ||
        query.contains('playaddrkey=') ||
        value.toLowerCase().contains('/video/');
  }

  /// 通过输入链接粗略推断来源平台，用于 Provider 未返回平台字段时兜底。
  static String inferPlatform(String sourceUrl) {
    final host =
        Uri.tryParse(sourceUrl)?.host.toLowerCase() ?? sourceUrl.toLowerCase();
    if (host.contains('douyin')) {
      return 'douyin';
    }
    if (host.contains('kuaishou') || host.contains('yximgs')) {
      return 'kuaishou';
    }
    if (host.contains('xiaohongshu') || host.contains('xhslink')) {
      return 'xiaohongshu';
    }
    if (host.contains('bilibili') || host.contains('b23.tv')) {
      return 'bilibili';
    }
    if (host.contains('youtube') || host.contains('youtu.be')) {
      return 'youtube';
    }
    if (host.contains('tiktok')) {
      return 'tiktok';
    }
    if (host.contains('twitter') || host.contains('x.com')) {
      return 'twitter';
    }
    return '';
  }

  /// 清理 HTML 标签和实体，Dart 核心库没有 HTML 反转义，先覆盖常见实体。
  static String cleanHtmlText(String value) {
    return value
        .replaceAll(RegExp('<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
