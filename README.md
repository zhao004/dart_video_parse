# dart_video_parse

`dart_video_parse` 是一个面向 Flutter Android/iOS 的聚合视频解析包。它把多个解析源封装成统一的 Dart
调用入口，让用户设备直接通过自身网络访问解析源，减少业务服务端代理、带宽和 IP 压力。

## 功能定位

- 聚合多个视频来源的解析能力，向 Flutter 层暴露统一接口。
- 屏蔽不同平台返回结构差异，减少业务代码中的适配逻辑。
- 支持轮询解析、指定解析源解析、解析源目录和解析源网络状态探测。
- 适合作为 Flutter App 的视频解析基础库，而不是独立播放器。

## 项目结构

```text
lib/
  dart_video_parse.dart   # 包入口、公共导出和 VideoParser 实现
  models/                 # 统一响应、结果、资源和 Provider 模型
  providers/              # Provider 基类、异常、测试 Provider 和单源实现
  providers.dart          # 解析源注册表和 Provider part 入口
  utils/                  # 加密、签名、URL、JSON、表单和 HTML 工具
test/
  dart_video_parse_test.dart
pubspec.yaml              # 包信息、SDK 约束和依赖声明
analysis_options.yaml     # flutter_lints 静态分析配置
```

## 安装与接入

在 Flutter 项目的 `pubspec.yaml` 中添加依赖。当前仓库本地开发可使用路径依赖：

```yaml
dependencies:
  dart_video_parse:
    path: ../dart_video_parse
```

然后执行：

```bash
flutter pub get
```

在 Dart 代码中导入包入口：

```dart
import 'package:dart_video_parse/dart_video_parse.dart';
```

## 基本用法

### 轮询解析

`parse` 会按优先级调用所有已启用的解析源，并返回首个包含有效视频或图片资源的结果。输入可以是纯 URL，也可以是包含 URL 的分享文案。

```dart
Future<void> parseExample() async {
  final parser = VideoParser();
  final response = await parser.parse('https://example.com/video');

  if (!response.success || response.data == null) {
    print('解析失败 [${response.code}]: ${response.msg}');
    return;
  }

  final result = response.data!;
  if (result.isVideo && result.videos.isNotEmpty) {
    final playableUrl = result.videos.first.url;
    print('视频地址: $playableUrl');
  } else if (result.isGallery && result.images.isNotEmpty) {
    print('图集包含 ${result.images.length} 张图片');
  }
}
```

`response.success` 可用于判断是否成功；失败时 `data` 为 `null`，可通过 `code` 和 `msg` 读取错误信息。`ParseResult.mediaType`、`isVideo` 和 `isGallery` 用于区分视频与图集结果。

### 指定解析源

只调用指定的解析源时，使用 `parseByProvider`：

```dart
Future<void> parseByProviderExample() async {
  final parser = VideoParser();
  final response = await parser.parseByProvider(
    'https://example.com/video',
    VideoParseProvider.kit9,
  );
  print(response.msg);
}
```

如果指定的解析源未注册或解析失败，该方法会返回失败的 `ParseResponse`，不会把 Provider 异常直接抛给调用方。

### 列出解析源

`listProviders` 返回当前 `VideoParser` 实例中已启用的解析源；传入自定义 Provider 列表时，返回值会按优先级排序。

```dart
final parser = VideoParser();
final providers = parser.listProviders();
for (final provider in providers) {
  print(
    '${provider.name}: ${provider.displayName} '
    '(priority=${provider.priority}, enabled=${provider.enabled})',
  );
}
```

### 探测解析源状态

`listProvidersStatus` 会并发请求各解析源的探测地址，返回当前设备网络下的可达性和延迟信息：

```dart
Future<void> probeProvidersExample() async {
  final parser = VideoParser();
  final statuses = await parser.listProvidersStatus();
  for (final status in statuses) {
    final latency = status.latencyMs == null
        ? '失败'
        : '${status.latencyMs} ms';
    print('${status.name}: available=${status.available}, latency=$latency');
  }
}
```

网络探测结果只反映探测请求是否可达，不代表该解析源一定能成功解析某个具体链接。

## 当前解析源

默认注册并按优先级轮询以下解析源：

1. `parsevideo`
2. `spapi`
3. `kedou`
4. `xtdowner`
5. `gljlw`
6. `33tool`
7. `kit9`
8. `woofmonster`
9. `qwkuns`
10. `nologo`
11. `bugpk`
12. `kukutool`
13. `vget`
14. `snapany`
15. `qzxdp`

说明：`xtdowner` 已保留 Provider 入口和状态探测入口，但其解析签名依赖原站 WASM 运行时。当前移动端纯 Dart
版本会返回明确失败，不会阻断其它解析源轮询。

## 输入与错误处理

- 仅接受 `http://` 或 `https://` 链接；空字符串、非法 URL 和其他协议会返回 `ParseCodes.badRequest`。
- 粘贴分享文案时，解析器会先提取其中出现的第一个 HTTP/HTTPS 链接。
- 所有默认解析源都失败时，`response.success` 为 `false`，应使用 `code` 和 `msg` 展示或记录错误。
- 解析结果只有包含至少一个有效视频或图片地址时才会被视为成功结果。

## 开发命令

```bash
flutter pub get
dart format .
dart analyze
flutter test
```

- `dart format .`：统一格式化源码和测试。
- `dart analyze`：按 `flutter_lints` 检查代码质量。
- `flutter test`：运行所有测试，验证解析逻辑和边界场景。

## 开发约定

- 公共 API 使用 `///` 文档说明用途、输入约束、异常策略和边界行为。
- 解析结果应使用明确模型承载，避免直接返回松散的 `Map`。
- 输入 URL 必须做合法性校验，不支持的来源要返回可识别错误。
- 新增解析器时同步补充单元测试，覆盖正常解析、空输入、非法 URL、超时或异常响应。

## 发布前检查

发布或合并前至少运行：

```bash
dart analyze
flutter test
```

如准备发布到 pub.dev，可先执行：

```bash
flutter pub publish --dry-run
```

## 相关链接

- 社区：[Linux.do](https://linux.do/)
- 更多开源项目：[zhao04 的公开主题](https://linux.do/u/zhao04/activity/topics)

## 免责声明

本项目中的数据来源于互联网收集。如涉及侵权，请提交 Issue，我将及时删除相关内容。

## 许可证

本项目使用 `LICENSE` 文件中声明的许可证。
