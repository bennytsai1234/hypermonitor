class HyperData {
  final DateTime timestamp;
  final int walletCount;
  final int openPositionCount;
  final String openPositionPct;
  final int profitCount;
  final int lossCount;
  final String longVolDisplay;
  final String shortVolDisplay;
  final String netVolDisplay;
  final String sentiment;
  
  final double longVolNum;
  final double shortVolNum;
  final double netVolNum;

  final CoinPosition? btc;
  final CoinPosition? eth;

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

  Map<String, dynamic> toJson() => {
    't': timestamp.millisecondsSinceEpoch,
    'wc': walletCount,
    'oc': openPositionCount,
    'op': openPositionPct,
    'pc': profitCount,
    'lc': lossCount,
    'ld': longVolDisplay,
    'sd': shortVolDisplay,
    'nd': netVolDisplay,
    's': sentiment,
    'ln': longVolNum,
    'sn': shortVolNum,
    'nn': netVolNum,
    'btc': btc?.toJson(),
    'eth': eth?.toJson(),
  };

  factory HyperData.fromJson(Map<String, dynamic> j) => HyperData(
    timestamp: DateTime.fromMillisecondsSinceEpoch(j['t']),
    walletCount: j['wc'],
    openPositionCount: j['oc'],
    openPositionPct: j['op'],
    profitCount: j['pc'],
    lossCount: j['lc'],
    longVolDisplay: j['ld'],
    shortVolDisplay: j['sd'],
    netVolDisplay: j['nd'],
    sentiment: j['s'],
    longVolNum: j['ln'],
    shortVolNum: j['sn'],
    netVolNum: j['nn'],
    btc: j['btc'] != null ? CoinPosition.fromJson(j['btc']) : null,
    eth: j['eth'] != null ? CoinPosition.fromJson(j['eth']) : null,
  );
}

class CoinPosition {
  final String? symbol;
  final double? longVol;
  final double? shortVol;
  final double? totalVol;
  final double? netVol;
  final String? longDisplay;
  final String? shortDisplay;
  final String? totalDisplay;
  final String? netDisplay;

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

  Map<String, dynamic> toJson() => {
    's': symbol, 'lv': longVol, 'sv': shortVol, 'tv': totalVol, 'nv': netVol,
    'ld': longDisplay, 'sd': shortDisplay, 'td': totalDisplay, 'nd': netDisplay,
  };

  factory CoinPosition.fromJson(Map<String, dynamic> j) => CoinPosition(
    symbol: j['s'], longVol: j['lv'], shortVol: j['sv'], totalVol: j['tv'], netVol: j['nv'],
    longDisplay: j['ld'], shortDisplay: j['sd'], totalDisplay: j['td'], netDisplay: j['nd'],
  );
}