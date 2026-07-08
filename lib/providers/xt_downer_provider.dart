part of '../providers.dart';

class XtDownerProvider extends BaseVideoProvider {
  const XtDownerProvider();

  @override
  VideoParseProvider get provider => VideoParseProvider.xtdowner;

  @override
  String get displayName => 'XTDowner';

  @override
  int get priority => 5;

  @override
  String get baseUrl => 'https://www.xtdowner.com';

  @override
  String get probeUrl => '$baseUrl/video/';

  @override
  Future<ParseResult> parse(String url, Dio client) async {
    throw const ProviderException('XTDowner 依赖 WASM 签名运行时，当前 Dart 移动端版本暂未启用');
  }
}
