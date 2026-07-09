import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dart_video_parse/dart_video_parse.dart';
import 'package:dart_video_parse/providers.dart';
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
            provider: VideoParseProvider.parsevideo,
            displayName: '空媒体源',
            priority: 1,
            baseUrl: 'https://empty.example',
            handler: (url) async =>
                ParseResult(type: 'video', title: '只有标题没有媒体', sourceUrl: url),
          ),
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
      final data = json['data'] as Map<String, Object?>;
      expect(data['parser_used'], 'kit9');
      expect(data['type'], 'video');
      expect(data['media_type'], 'video');
      expect(data['is_video'], isTrue);
      expect(data['is_gallery'], isFalse);
    });

    test('只有元数据没有媒体资源时结果无效', () {
      const result = ParseResult(type: 'video', title: '只有标题');

      expect(result.isValid, isFalse);
    });

    test('媒体类型根据有效资源统一归一，避免前端混淆', () {
      const mixed = ParseResult(
        type: 'gallery',
        videos: [VideoItem(url: 'https://cdn.example/video.mp4')],
        images: [ImageItem(url: 'https://cdn.example/cover.jpg')],
      );
      const gallery = ParseResult(
        type: 'video',
        images: [ImageItem(url: 'https://cdn.example/1.jpg')],
      );
      const invalid = ParseResult(
        type: 'unexpected',
        videos: [VideoItem(url: ' ')],
        images: [ImageItem(url: '')],
      );

      expect(mixed.mediaType, ParseMediaType.video);
      expect(mixed.isVideo, isTrue);
      expect(mixed.isGallery, isFalse);
      expect(mixed.toJson()['type'], 'video');
      expect(mixed.toJson()['declared_type'], 'gallery');
      expect(mixed.toJson()['videos_count'], 1);
      expect(mixed.toJson()['images_count'], 1);

      expect(gallery.mediaType, ParseMediaType.gallery);
      expect(gallery.isVideo, isFalse);
      expect(gallery.isGallery, isTrue);
      expect(gallery.toJson()['type'], 'gallery');
      expect(gallery.toJson()['media_type'], 'gallery');

      expect(invalid.isValid, isFalse);
      expect(invalid.mediaType, ParseMediaType.unknown);
      expect(invalid.toJson()['type'], 'unknown');
    });

    test('资源 URL 类型判断能识别抖音图集图片和视频直链', () {
      const imageUrl =
          'https://p5-ex-gddgtc-sign.douyinpic.com/tos-cn-i-0813c000-ce/'
          'sample~tplv-dy-aweme-images-ds-rs-v1:1920:1280:q80.jpeg'
          '?sc=image&biz_tag=aweme_images';
      const videoUrl =
          'https://v11-default.365yg.com/token/video/tos/cn/path/'
          '?mime_type=video_mp4&playAddrKey=v0200';
      const textValue = '阳朔风光#风光摄影 #每一帧都是壁纸';

      expect(ParseUtils.isHttpUrl(imageUrl), isTrue);
      expect(ParseUtils.isImageUrl(imageUrl), isTrue);
      expect(ParseUtils.isVideoUrl(imageUrl), isFalse);

      expect(ParseUtils.isHttpUrl(videoUrl), isTrue);
      expect(ParseUtils.isVideoUrl(videoUrl), isTrue);
      expect(ParseUtils.isImageUrl(videoUrl), isFalse);

      expect(ParseUtils.isHttpUrl(textValue), isFalse);
      expect(ParseUtils.isImageUrl(textValue), isFalse);
      expect(ParseUtils.isVideoUrl(textValue), isFalse);
    });

    test('Kit9 图集列表资源不会被误判为视频直链', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<Object?>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'code': 200,
                    'type': 'douyin',
                    'data': {
                      'video_title': '图集标题',
                      'video_link': [
                        {
                          'type': 'image',
                          'url':
                              'https://p3-pc-sign.douyinpic.com/a.webp'
                              '?biz_tag=aweme_images&sc=image',
                        },
                        {
                          'type': 'image',
                          'url':
                              'https://p3-pc-sign.douyinpic.com/b.webp'
                              '?biz_tag=aweme_images&sc=image',
                        },
                      ],
                    },
                  },
                ),
              );
            },
          ),
        );

      final result = await const Kit9Provider().parse(
        'https://v.douyin.com/gallery',
        dio,
      );

      expect(result.mediaType, ParseMediaType.gallery);
      expect(result.videos, isEmpty);
      expect(result.images, hasLength(2));
      expect(result.toJson()['type'], 'gallery');
      expect(result.toJson()['images_count'], 2);
    });

    test('多个公开源站不会把图集资源误收进视频列表', () async {
      const imageUrl =
          'https://p3-pc-sign.douyinpic.com/tos-cn-i-demo/a.webp'
          '?biz_tag=aweme_images&sc=image';
      const sourceUrl = 'https://v.douyin.com/gallery';
      final cases = <({String name, BaseVideoProvider provider, Object? data})>[
        (
          name: 'bugpk',
          provider: const BugPkProvider(),
          data: {
            'code': 200,
            'data': {
              'type': 'video',
              'url': imageUrl,
              'images': [imageUrl],
            },
          },
        ),
        (
          name: 'nologo',
          provider: const NologoProvider(),
          data: {
            'code': 200,
            'data': {
              'type': 'video',
              'url': imageUrl,
              'pics': [imageUrl],
            },
          },
        ),
        (
          name: 'qzxdp',
          provider: const QzxdpProvider(),
          data: {
            'data': {
              'url': imageUrl,
              'images': [imageUrl],
            },
          },
        ),
        (
          name: 'snapany',
          provider: const SnapAnyProvider(),
          data: {
            'code': 0,
            'medias': [
              {
                'media_type': 'video',
                'resource_url': imageUrl,
                'preview_url': imageUrl,
                'formats': [
                  {'video_url': imageUrl},
                ],
              },
            ],
          },
        ),
        (
          name: 'cobalt',
          provider: const WoofMonsterProvider(),
          data: {
            'status': 'picker',
            'picker': [
              {'type': 'video', 'url': imageUrl},
            ],
          },
        ),
      ];

      for (final item in cases) {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.resolve(
                  Response<Object?>(
                    requestOptions: options,
                    statusCode: 200,
                    data: item.data,
                  ),
                );
              },
            ),
          );

        final result = await item.provider.parse(sourceUrl, dio);

        expect(result.mediaType, ParseMediaType.gallery, reason: item.name);
        expect(result.videos, isEmpty, reason: item.name);
        expect(result.images, isNotEmpty, reason: item.name);
      }
    });

    test('SPAPI 重试请求使用首页返回的动态 AppKey', () async {
      const dynamicAppKey = 'dynamic-session-key';
      const inputUrl = 'https://example.com/share';
      var postWasEncryptedWithDynamicKey = false;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.method == 'GET' &&
                  options.uri.toString() == 'https://spapi.cn/') {
                handler.resolve(
                  Response<Object?>(
                    requestOptions: options,
                    statusCode: 200,
                    headers: Headers.fromMap({
                      'set-cookie': ['KFAPI_APPKEY=$dynamicAppKey; Path=/'],
                    }),
                  ),
                );
                return;
              }

              if (options.method == 'POST' &&
                  options.uri.host == 'api.spapi.cn') {
                final plainRequest = CryptoHelpers.opensslAesDecrypt(
                  options.data.toString(),
                  dynamicAppKey,
                );
                postWasEncryptedWithDynamicKey = plainRequest == inputUrl;
                final payload = jsonEncode({
                  'status': '101',
                  'data': {
                    'title': '动态 key 视频',
                    'video': 'https://cdn.example/spapi.mp4',
                  },
                });
                handler.resolve(
                  Response<String>(
                    requestOptions: options,
                    statusCode: 200,
                    data: CryptoHelpers.opensslAesEncrypt(
                      payload,
                      dynamicAppKey,
                    ),
                  ),
                );
                return;
              }

              handler.reject(
                DioException(
                  requestOptions: options,
                  error: '未预期请求: ${options.method} ${options.uri}',
                ),
              );
            },
          ),
        );
      final parser = VideoParser(dio: dio, providers: const [SpapiProvider()]);

      final response = await parser.parse(inputUrl);

      expect(response.success, isTrue);
      expect(postWasEncryptedWithDynamicKey, isTrue);
      expect(response.data?.videos.single.url, 'https://cdn.example/spapi.mp4');
    });
  });
}
