/// Provider 内部异常，统一由调度器转换为失败响应。
class ProviderException implements Exception {
  const ProviderException(this.message);

  /// 面向调用方的错误摘要。
  final String message;

  @override
  String toString() => message;
}
