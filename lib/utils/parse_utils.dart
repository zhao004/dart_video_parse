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
  static Map<String, Object?> mapValue(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
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
