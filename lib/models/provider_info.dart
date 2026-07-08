import 'video_parse_provider.dart';

/// 解析源目录信息。
class ProviderInfo {
  const ProviderInfo({
    required this.provider,
    required this.name,
    required this.displayName,
    required this.priority,
    required this.baseUrl,
    required this.enabled,
  });

  /// 枚举值，方便调用指定源。
  final VideoParseProvider provider;

  /// Provider 名称。
  final String name;

  /// 面向界面展示的名称。
  final String displayName;

  /// 轮询优先级，数字越小越优先。
  final int priority;

  /// 主域名或接口域名。
  final String baseUrl;

  /// 是否参与默认轮询。
  final bool enabled;

  Map<String, Object?> toJson() => {
    'name': name,
    'display_name': displayName,
    'priority': priority,
    'base_url': baseUrl,
    'enabled': enabled,
  };
}
