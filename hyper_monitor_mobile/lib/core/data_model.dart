import 'package:isar/isar.dart';

part 'data_model.g.dart';

@collection
class HyperData {
  Id id = Isar.autoIncrement;

  DateTime timestamp;
  int walletCount;
  int openPositionCount;
  String openPositionPct;
  int profitCount;
  int lossCount;
  String longVolDisplay;
  String shortVolDisplay;
  String netVolDisplay;
  String sentiment;
  
  double longVolNum;
  double shortVolNum;
  double netVolNum;

  CoinPosition? btc;
  CoinPosition? eth;

  HyperData({
    required this.timestamp,
    required this.walletCount,
    required this.openPositionCount,
    required this.openPositionPct,
    required this.profitCount,
    required this.lossCount,
    required this.longVolDisplay,
    required this.shortVolDisplay,
    required this.netVolDisplay,
    required this.sentiment,
    required this.longVolNum,
    required this.shortVolNum,
    required this.netVolNum,
    this.btc,
    this.eth,
  });
}

@embedded
class CoinPosition {
  String? symbol;
  double? longVol;
  double? shortVol;
  double? totalVol;
  double? netVol;
  String? longDisplay;
  String? shortDisplay;
  String? totalDisplay;
  String? netDisplay;

  CoinPosition({
    this.symbol,
    this.longVol,
    this.shortVol,
    this.totalVol,
    this.netVol,
    this.longDisplay,
    this.shortDisplay,
    this.totalDisplay,
    this.netDisplay,
  });
}
