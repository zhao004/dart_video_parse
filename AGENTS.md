# Repository Guidelines

## Project Structure & Module Organization

本仓库是 Flutter/Dart 包 `dart_video_parse`。可复用源码放在 `lib/`，单元测试或组件测试放在 `test/`。项目元数据与依赖声明位于 `pubspec.yaml`，静态分析配置位于 `analysis_options.yaml`。不要修改生成目录或依赖产物，例如 `.dart_tool/`、`build/`、`.git/`、`pubspec.lock`。

## Build, Test, and Development Commands

- `flutter pub get`：根据 `pubspec.yaml` 安装依赖。
- `dart analyze`：使用 `flutter_lints` 执行静态分析。
- `dart format .`：使用官方格式化器处理 Dart 源码与测试。
- `flutter test`：运行 `test/` 下的全部测试。
- `flutter pub publish --dry-run`：发布前检查包元数据与文件清单。

除非明确要求，不要构建 APK 或启动开发服务。常规改动优先使用分析与测试完成验证。

## Coding Style & Naming Conventions

遵循 Dart 官方风格：两个空格缩进，变量与方法使用 `lowerCamelCase`，类名使用 `UpperCamelCase`，文件名使用 `snake_case.dart`。保持 API 小而聚焦，命名要表达意图，避免魔法值。公共 API 使用 `///` 文档说明设计意图、边界条件与异常行为。注释应解释取舍和特殊情况，不重复代码表面含义。

## Testing Guidelines

使用 `flutter_test` 编写测试。测试文件以 `_test.dart` 结尾，并尽量对应被测源码位置，例如 `lib/video_parser.dart` 对应 `test/video_parser_test.dart`。测试应覆盖输入校验、边界条件与异常路径。提交功能改动前必须运行 `flutter test`。

## Commit & Pull Request Guidelines

当前没有可用提交历史可推断项目惯例，因此使用中文 Conventional Commits：`<type>(scope): 描述`，例如 `feat(parser): 新增视频地址解析`。每个提交只包含一个逻辑改动。Pull Request 应包含变更摘要、关联 issue、已运行的验证命令；仅在 UI 行为变化时附截图。

## Security & Configuration Tips

不要硬编码密钥、令牌或凭据。使用环境变量或已记录的本地配置。不要提交生成文件、构建产物或个人 IDE 状态。
