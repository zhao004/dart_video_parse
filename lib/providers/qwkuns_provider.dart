part of '../providers.dart';

class QwkunsProvider extends CobaltProvider {
  const QwkunsProvider();

  @override
  VideoParseProvider get provider => VideoParseProvider.qwkuns;

  @override
  String get displayName => 'QWKuns';

  @override
  int get priority => 10;

  @override
  String get baseUrl => 'https://qwkuns.me';
}
