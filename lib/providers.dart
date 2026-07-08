import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';

import 'models/media_items.dart';
import 'models/parse_result.dart';
import 'models/video_parse_provider.dart';
import 'providers/base_video_provider.dart';
import 'providers/provider_exception.dart';
import 'utils/crypto_helpers.dart';
import 'utils/parse_utils.dart';

part 'providers/json_provider.dart';
part 'providers/parse_video_provider.dart';
part 'providers/spapi_provider.dart';
part 'providers/kedou_provider.dart';
part 'providers/xt_downer_provider.dart';
part 'providers/gljlw_provider.dart';
part 'providers/tool33_provider.dart';
part 'providers/kit9_provider.dart';
part 'providers/cobalt_provider.dart';
part 'providers/woof_monster_provider.dart';
part 'providers/qwkuns_provider.dart';
part 'providers/nologo_provider.dart';
part 'providers/bug_pk_provider.dart';
part 'providers/kuku_tool_provider.dart';
part 'providers/vget_provider.dart';
part 'providers/snap_any_provider.dart';
part 'providers/qzxdp_provider.dart';

/// 构建默认解析源注册表，优先级与原 Python 后端保持一致。
List<BaseVideoProvider> buildDefaultProviders() => const [
  ParseVideoProvider(),
  SpapiProvider(),
  KedouProvider(),
  XtDownerProvider(),
  GljlwProvider(),
  Tool33Provider(),
  Kit9Provider(),
  WoofMonsterProvider(),
  QwkunsProvider(),
  NologoProvider(),
  BugPkProvider(),
  KukuToolProvider(),
  VgetProvider(),
  SnapAnyProvider(),
  QzxdpProvider(),
];
