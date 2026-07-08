import 'dart:async';

import 'package:dio/dio.dart';

import 'models/parse_codes.dart';
import 'models/parse_response.dart';
import 'models/provider_info.dart';
import 'models/provider_status.dart';
import 'models/video_parse_provider.dart';
import 'providers.dart';
import 'providers/base_video_provider.dart';
import 'utils/parse_utils.dart';

export 'models/media_items.dart';
export 'models/parse_codes.dart';
export 'models/parse_response.dart';
export 'models/parse_result.dart';
export 'models/provider_info.dart';
export 'models/provider_status.dart';
export 'models/video_parse_provider.dart';
export 'providers/base_video_provider.dart';
export 'providers/provider_exception.dart';
export 'providers/test_video_provider.dart';
export 'utils/crypto_helpers.dart';
export 'utils/parse_utils.dart';

const _defaultConnectTimeout = Duration(seconds: 12);
const _defaultReceiveTimeout = Duration(seconds: 30);
const _statusProbeTimeout = Duration(seconds: 5);

/// Flutter 移动端视频解析统一入口。
///
/// 设计意图：业务侧只依赖这个类，不直接感知各解析源的请求参数、签名、
/// 返回结构差异。解析失败会被转换为 [ParseResponse]，避免异常泄漏到界面层。
class VideoParser {
  VideoParser({Dio? dio, List<BaseVideoProvider>? providers})
    : _dio = dio ?? _createDefaultDio(),
      _providers =
          (providers ?? buildDefaultProviders())
              .where((item) => item.enabled)
              .toList()
            ..sort((left, right) => left.priority.compareTo(right.priority)) {
    _providerIndex = {for (final item in _providers) item.provider: item};
  }

  final Dio _dio;
  final List<BaseVideoProvider> _providers;
  late final Map<VideoParseProvider, BaseVideoProvider> _providerIndex;

  /// 按优先级轮询所有解析源，首个有效结果即返回。
  Future<ParseResponse> parse(String url) async {
    final normalizedUrl = _normalizeInputUrl(url);
    final validationError = _validateUrl(normalizedUrl);
    if (validationError != null) {
      return ParseResponse.failure(
        validationError,
        code: ParseCodes.badRequest,
      );
    }

    final errors = <String>[];
    for (final provider in _providers) {
      try {
        final result = await provider.parse(normalizedUrl, _dio);
        if (!result.isValid) {
          errors.add('${provider.name}: 返回数据为空或无效');
          continue;
        }
        return ParseResponse.success(
          result.copyWith(parserUsed: provider.name),
          '解析成功 (使用 ${provider.name})',
        );
      } catch (error) {
        errors.add('${provider.name}: ${provider.wrapError(error).message}');
      }
    }

    final suffix = errors.isEmpty ? '' : '：${errors.take(3).join(' | ')}';
    return ParseResponse.failure('所有解析接口均无法解析此链接$suffix');
  }

  /// 只使用指定解析源解析链接。
  Future<ParseResponse> parseByProvider(
    String url,
    VideoParseProvider provider,
  ) async {
    final normalizedUrl = _normalizeInputUrl(url);
    final validationError = _validateUrl(normalizedUrl);
    if (validationError != null) {
      return ParseResponse.failure(
        validationError,
        code: ParseCodes.badRequest,
      );
    }

    final target = _providerIndex[provider];
    if (target == null) {
      return ParseResponse.failure(
        '未找到提供方: ${provider.name}',
        code: ParseCodes.notFound,
      );
    }

    try {
      final result = await target.parse(normalizedUrl, _dio);
      if (!result.isValid) {
        return ParseResponse.failure('${target.name}: 返回数据为空或无效');
      }
      return ParseResponse.success(
        result.copyWith(parserUsed: target.name),
        '解析成功 (使用 ${target.name})',
      );
    } catch (error) {
      return ParseResponse.failure(target.wrapError(error).message);
    }
  }

  /// 返回全部已注册解析源。
  List<ProviderInfo> listProviders() =>
      _providers.map((item) => item.info).toList();

  /// 并发探测所有解析源基础地址延迟，供前端预览用户网络状态。
  Future<List<ProviderStatus>> listProvidersStatus() async {
    final futures = _providers.map(_probeProviderStatus);
    final statuses = await Future.wait(futures);
    statuses.sort((left, right) => left.name.compareTo(right.name));
    return statuses;
  }

  Future<ProviderStatus> _probeProviderStatus(
    BaseVideoProvider provider,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio
          .get<Object?>(
            provider.probeUrl,
            options: Options(
              followRedirects: true,
              receiveDataWhenStatusError: true,
              validateStatus: (_) => true,
            ),
          )
          .timeout(_statusProbeTimeout);
      stopwatch.stop();
      final statusCode = response.statusCode;
      final reachable = statusCode != null;
      final available =
          statusCode != null && statusCode >= 200 && statusCode < 400;
      return ProviderStatus(
        provider: provider.provider,
        name: provider.name,
        probeUrl: provider.probeUrl,
        reachable: reachable,
        available: available,
        latencyMs: stopwatch.elapsedMilliseconds,
        httpStatusCode: statusCode,
        errorMessage: available ? '' : 'HTTP ${statusCode ?? 'unknown'}',
      );
    } catch (error) {
      stopwatch.stop();
      return ProviderStatus(
        provider: provider.provider,
        name: provider.name,
        probeUrl: provider.probeUrl,
        reachable: false,
        available: false,
        latencyMs: null,
        httpStatusCode: null,
        errorMessage: error.toString(),
      );
    }
  }

  static Dio _createDefaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: _defaultConnectTimeout,
        receiveTimeout: _defaultReceiveTimeout,
        sendTimeout: _defaultConnectTimeout,
        responseType: ResponseType.json,
      ),
    );
  }

  static String _normalizeInputUrl(String url) => ParseUtils.firstHttpUrl(url);

  static String? _validateUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return '待解析链接不能为空';
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return '待解析链接格式无效';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '待解析链接格式无效，必须以 http:// 或 https:// 开头';
    }
    return null;
  }
}
