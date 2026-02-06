class CoinPosition {
  final String symbol;
  final double longVol;
  final double shortVol;
  final double totalVol;
  final double netVol; 
  final String longDisplay;
  final String shortDisplay;
  final String totalDisplay;
  final String netDisplay;

  CoinPosition({
    required this.symbol,
    required this.longVol,
    required this.shortVol,
    required this.totalVol,
    required this.netVol,
    required this.longDisplay,
    required this.shortDisplay,
    required this.totalDisplay,
    required this.netDisplay,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'longVol': longVol,
    'shortVol': shortVol,
    'totalVol': totalVol,
    'netVol': netVol,
    'longDisplay': longDisplay,
    'shortDisplay': shortDisplay,
    'totalDisplay': totalDisplay,
    'netDisplay': netDisplay,
  };

  factory CoinPosition.fromJson(Map<String, dynamic> j) => CoinPosition(
    symbol: j['symbol'] ?? "",
    longVol: (j['longVol'] ?? 0.0).toDouble(),
    shortVol: (j['shortVol'] ?? 0.0).toDouble(),
    totalVol: (j['totalVol'] ?? 0.0).toDouble(),
    netVol: (j['netVol'] ?? 0.0).toDouble(),
    longDisplay: j['longDisplay'] ?? "",
    shortDisplay: j['shortDisplay'] ?? "",
    totalDisplay: j['totalDisplay'] ?? "",
    netDisplay: j['netDisplay'] ?? "",
  );
}

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
    'timestamp': timestamp.toIso8601String(),
    'walletCount': walletCount,
    'openPositionCount': openPositionCount,
    'openPositionPct': openPositionPct,
    'profitCount': profitCount,
    'lossCount': lossCount,
    'longVolDisplay': longVolDisplay,
    'shortVolDisplay': shortVolDisplay,
    'netVolDisplay': netVolDisplay,
    'sentiment': sentiment,
    'longVolNum': longVolNum,
    'shortVolNum': shortVolNum,
    'netVolNum': netVolNum,
    'btc': btc?.toJson(),
    'eth': eth?.toJson(),
  };

  factory HyperData.fromJson(Map<String, dynamic> j) => HyperData(
    timestamp: DateTime.parse(j['timestamp']),
    walletCount: j['walletCount'] ?? 0,
    openPositionCount: j['openPositionCount'] ?? 0,
    openPositionPct: j['openPositionPct'] ?? "",
    profitCount: j['profitCount'] ?? 0,
    lossCount: j['lossCount'] ?? 0,
    longVolDisplay: j['longVolDisplay'] ?? "",
    shortVolDisplay: j['shortVolDisplay'] ?? "",
    netVolDisplay: j['netVolDisplay'] ?? "",
    sentiment: j['sentiment'] ?? "",
    longVolNum: (j['longVolNum'] ?? 0.0).toDouble(),
    shortVolNum: (j['shortVolNum'] ?? 0.0).toDouble(),
    netVolNum: (j['netVolNum'] ?? 0.0).toDouble(),
    btc: j['btc'] != null ? CoinPosition.fromJson(j['btc']) : null,
    eth: j['eth'] != null ? CoinPosition.fromJson(j['eth']) : null,
  );
}