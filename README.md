# dart_video_parse

`dart_video_parse` 是一个面向 Flutter Android/iOS 的聚合视频解析包。它把多个解析源封装成统一 Dart 调用入口，让用户设备直接通过自身网络访问解析源，减少业务服务端代理、带宽和 IP 压力。

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

在 Flutter 项目的 `pubspec.yaml` 中添加依赖：

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

## 预期使用方式

公共 API 保持 Flutter 侧调用简单、结果结构稳定，并明确区分解析成功、输入非法、来源不支持和网络异常等情况。

```dart
final parser = VideoParser();

// 按内置优先级轮询解析源，首个有效结果会返回成功。
final response = await parser.parse('https://example.com/video');

if (response.success) {
  final result = response.data!;
  final playableUrl = result.videos.isNotEmpty ? result.videos.first.url : '';
}
```

指定解析源：

```dart
final response = await parser.parseByProvider(
  'https://example.com/video',
  VideoParseProvider.kit9,
);
```

列出解析源：

```dart
final providers = parser.listProviders();
```

探测用户当前网络到各解析源的状态：

```dart
final statuses = await parser.listProvidersStatus();

for (final status in statuses) {
  print('${status.name}: ${status.latencyMs}ms ${status.available}');
}
```

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

说明：`xtdowner` 已保留 Provider 入口和状态探测入口，但其解析签名依赖原站 WASM 运行时。当前移动端纯 Dart 版本会返回明确失败，不会阻断其它解析源轮询。

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

## 许可证

本项目使用 `LICENSE` 文件中声明的许可证。
