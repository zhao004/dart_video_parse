import 'package:dio/dio.dart';

import '../models/parse_result.dart';
import '../models/video_parse_provider.dart';
import 'base_video_provider.dart';

/// 动态测试 Provider，用于单元测试注入，不参与默认注册表。
class TestVideoProvider extends BaseVideoProvider {
  const TestVideoProvider({
    required this.provider,
    required this.displayName,
    required this.priority,
    required this.baseUrl,
    required this.handler,
    this.enabled = true,
  });

  @override
  final VideoParseProvider provider;

  @override
  final String displayName;

  @override
  final int priority;

  @override
  final String baseUrl;

  @override
  final bool enabled;

  /// 测试注入的解析函数，避免单元测试依赖真实网络。
  final Future<ParseResult> Function(String url) handler;

  @override
  Future<ParseResult> parse(String url, Dio client) => handler(url);
}
