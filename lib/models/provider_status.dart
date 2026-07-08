import 'video_parse_provider.dart';

/// Provider 网络状态探测结果。
class ProviderStatus {
  const ProviderStatus({
    required this.provider,
    required this.name,
    required this.probeUrl,
    required this.reachable,
    required this.available,
    this.latencyMs,
    this.httpStatusCode,
    this.errorMessage = '',
  });

  /// 被探测的 Provider。
  final VideoParseProvider provider;

  /// Provider 名称。
  final String name;

  /// 实际探测地址。
  final String probeUrl;

  /// HTTPS 是否有响应或 TCP 层可达。
  final bool reachable;

  /// HTTP 状态是否表示可用。
  final bool available;

  /// 请求耗时，失败时为 `null`。
  final int? latencyMs;

  /// HTTP 状态码，网络失败时为 `null`。
  final int? httpStatusCode;

  /// 错误摘要。
  final String errorMessage;

  Map<String, Object?> toJson() => {
    'name': name,
    'probe_url': probeUrl,
    'reachable': reachable,
    'available': available,
    'latency_ms': latencyMs,
    'http_status_code': httpStatusCode,
    'error_message': errorMessage,
  };
}
