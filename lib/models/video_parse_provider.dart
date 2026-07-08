/// 当前包支持的视频解析源。
enum VideoParseProvider {
  parsevideo('parsevideo'),
  spapi('spapi'),
  kedou('kedou'),
  xtdowner('xtdowner'),
  gljlw('gljlw'),
  tool33('33tool'),
  kit9('kit9'),
  woofmonster('woofmonster'),
  qwkuns('qwkuns'),
  nologo('nologo'),
  bugpk('bugpk'),
  kukutool('kukutool'),
  vget('vget'),
  snapany('snapany'),
  qzxdp('qzxdp');

  const VideoParseProvider(this.name);

  /// 与原后端保持一致的解析源名称。
  final String name;

  /// 从字符串解析 Provider，非法名称返回 `null`，避免调用方自行捕获异常。
  static VideoParseProvider? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    for (final provider in values) {
      if (provider.name == normalized) {
        return provider;
      }
    }
    return null;
  }
}
