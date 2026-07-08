/// 统一业务错误码，保持和原服务端响应语义一致。
abstract final class ParseCodes {
  static const success = 0;
  static const badRequest = 400;
  static const forbidden = 403;
  static const notFound = 404;
  static const serverError = 500;
}
