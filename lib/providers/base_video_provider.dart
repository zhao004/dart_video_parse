import 'package:dio/dio.dart';

import '../models/parse_result.dart';
import '../models/provider_info.dart';
import '../models/video_parse_provider.dart';
import 'provider_exception.dart';

const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/131.0.0.0 Safari/537.36';

/// 所有解析源的统一内部接口。
abstract class BaseVideoProvider {
  const BaseVideoProvider();

  VideoParseProvider get provider;

  String get name => provider.name;

  String get displayName;

  int get priority;

  String get baseUrl;

  String get probeUrl => baseUrl;

  bool get enabled => true;

  /// 执行单个 Provider 的解析逻辑。
  Future<ParseResult> parse(String url, Dio client);

  ProviderInfo get info => ProviderInfo(
    provider: provider,
    name: name,
    displayName: displayName,
    priority: priority,
    baseUrl: baseUrl,
    enabled: enabled,
  );

  /// 安全转换字符串，屏蔽第三方接口的 `null` 和非字符串字段。
  String safeString(Object? value, {String defaultValue = ''}) {
    if (value == null) {
      return defaultValue;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? defaultValue : normalized;
  }

  /// 从文本中提取第一个 HTTP 链接，兼容用户粘贴分享文案。
  String extractFirstUrl(String text) {
    final match = RegExp(r'https?://[^\s|\u4e00-\u9fa5]+').firstMatch(text);
    if (match == null) {
      throw const ProviderException('未找到有效 http 链接');
    }
    return match.group(0)!.trim();
  }

  /// 构造移动端可用的浏览器请求头。
  Map<String, String> browserHeaders({
    String? accept,
    String? contentType,
    String? origin,
    String? referer,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{'User-Agent': _defaultUserAgent};
    if (accept != null) {
      headers['Accept'] = accept;
    }
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    if (origin != null) {
      headers['Origin'] = origin;
    }
    if (referer != null) {
      headers['Referer'] = referer;
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// 将 Dio/解析异常压缩成稳定错误文案。
  ProviderException wrapError(Object error) {
    if (error is ProviderException) {
      return error;
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      final reason = status == null ? error.message : 'HTTP $status';
      return ProviderException('$displayName 请求失败: $reason');
    }
    return ProviderException('$displayName 解析失败: $error');
  }
}
