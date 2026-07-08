import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoParser', () {
    test('拒绝空链接和非 http 链接', () async {
      final parser = VideoParser(providers: const []);

      final empty = await parser.parse('  ');
      final invalid = await parser.parse('ftp://example.com/video');

      expect(empty.success, isFalse);
      expect(empty.code, ParseCodes.badRequest);
      expect(invalid.success, isFalse);
      expect(invalid.code, ParseCodes.badRequest);
    });

    test('按优先级轮询并返回首个有效结果', () async {
      final parser = VideoParser(
        providers: [
          TestVideoProvider(
            provider: VideoParseProvider.kit9,
            displayName: '失败源',
            priority: 2,
            baseUrl: 'https://failed.example',
            handler: (_) async => throw const ProviderException('上游失败'),
          ),
          TestVideoProvider(
            provider: VideoParseProvider.spapi,
            displayName: '成功源',
            priority: 3,
            baseUrl: 'https://ok.example',
            handler: (url) async => ParseResult(
              type: 'video',
              title: '测试视频',
              videos: const [VideoItem(url: 'https://cdn.example/video.mp4')],
              sourceUrl: url,
            ),
          ),
        ],
      );

      final response = await parser.parse('https://example.com/share');

      expect(response.success, isTrue);
      expect(response.data?.parserUsed, 'spapi');
      expect(response.data?.videos.single.url, 'https://cdn.example/video.mp4');
    });

    test('解析分享文案时先提取首个 HTTP 链接', () async {
      const shareText =
          '1.58 02/23 :7pm dnd:/ O@x.Fu 傅老师讲述为什么没有抄底生猪 '
          '# 傅海棠 https://v.douyin.com/jgu4OsLilOQ/ 复制此链接';
      late String receivedUrl;
      final parser = VideoParser(
        providers: [
          TestVideoProvider(
            provider: VideoParseProvider.spapi,
            displayName: '成功源',
            priority: 1,
            baseUrl: 'https://ok.example',
            handler: (url) async {
              receivedUrl = url;
              return ParseResult(
                type: 'video',
                title: '分享视频',
                videos: const [VideoItem(url: 'https://cdn.example/share.mp4')],
                sourceUrl: url,
              );
            },
          ),
        ],
      );

      final response = await parser.parse(shareText);

      expect(response.success, isTrue);
      expect(receivedUrl, 'https://v.douyin.com/jgu4OsLilOQ/');
      expect(response.data?.sourceUrl, 'https://v.douyin.com/jgu4OsLilOQ/');
    });

    test('指定解析源只调用目标 Provider', () async {
      final parser = VideoParser(
        providers: [
          TestVideoProvider(
            provider: VideoParseProvider.kit9,
            displayName: 'Kit9',
            priority: 8,
            baseUrl: 'https://kit9.example',
            handler: (url) async => ParseResult(
              type: 'video',
              title: '指定源',
              videos: const [VideoItem(url: 'https://cdn.example/kit9.mp4')],
              sourceUrl: url,
            ),
          ),
        ],
      );

      final response = await parser.parseByProvider(
        'https://example.com/share',
        VideoParseProvider.kit9,
      );

      expect(response.success, isTrue);
      expect(response.data?.parserUsed, 'kit9');
    });

    test('列出全部默认解析源且顺序与优先级一致', () {
      final parser = VideoParser();
      final providers = parser.listProviders();

      expect(providers.length, 15);
      expect(providers.first.name, 'parsevideo');
      expect(
        providers.map((item) => item.priority),
        orderedEquals(providers.map((item) => item.priority).toList()..sort()),
      );
    });

    test('模型序列化保持统一字段', () {
      final response = ParseResponse.success(
        const ParseResult(
          type: 'video',
          title: '标题',
          videos: [VideoItem(url: 'https://cdn.example/a.mp4', quality: '原画')],
          parserUsed: 'kit9',
        ),
        '解析成功',
      );

      final json = response.toJson();

      expect(json['code'], ParseCodes.success);
      expect(json['msg'], '解析成功');
      expect((json['data'] as Map<String, Object?>)['parser_used'], 'kit9');
    });
  });
}
