import 'parse_codes.dart';
import 'parse_result.dart';

/// 统一解析响应，业务层只需要判断 [success]。
class ParseResponse {
  const ParseResponse({
    required this.code,
    required this.msg,
    required this.time,
    this.data,
  });

  /// 业务状态码。
  final int code;

  /// 响应消息。
  final String msg;

  /// 解析成功时的业务数据。
  final ParseResult? data;

  /// 秒级时间戳。
  final int time;

  /// 是否成功。
  bool get success => code == ParseCodes.success;

  factory ParseResponse.success(ParseResult data, String msg) {
    return ParseResponse(
      code: ParseCodes.success,
      msg: msg,
      data: data,
      time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  factory ParseResponse.failure(
    String msg, {
    int code = ParseCodes.serverError,
  }) {
    return ParseResponse(
      code: code,
      msg: msg,
      time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  Map<String, Object?> toJson() => {
    'code': code,
    'msg': msg,
    'data': data?.toJson(),
    'time': time,
  };
}
