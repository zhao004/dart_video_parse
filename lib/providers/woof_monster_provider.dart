part of '../providers.dart';

class WoofMonsterProvider extends CobaltProvider {
  const WoofMonsterProvider();

  @override
  VideoParseProvider get provider => VideoParseProvider.woofmonster;

  @override
  String get displayName => 'WoofMonster';

  @override
  int get priority => 9;

  @override
  String get baseUrl => 'https://dl.woof.monster';
}
