class CoinPosition {
  final String symbol;
  final double longVol;
  final double shortVol;
  final double totalVol;
  final String longDisplay;
  final String shortDisplay;
  final String totalDisplay;

  CoinPosition({
    required this.symbol,
    required this.longVol,
    required this.shortVol,
    required this.totalVol,
    required this.longDisplay,
    required this.shortDisplay,
    required this.totalDisplay,
  });
}

class HyperData {
  final DateTime timestamp;
  final int walletCount;

  // People counts
  final int openPositionCount;  // 開倉人數
  final String openPositionPct; // 開倉百分比 (50.87%)
  final int profitCount;        // 賺錢人數
  final int lossCount;          // 虧錢人數

  // Volume displays
  final String longVolDisplay;
  final String shortVolDisplay;
  final String netVolDisplay;

  // Sentiment (e.g. "看跌", "看涨")
  final String sentiment;

  // Numeric values for calculation
  final double longVolNum;
  final double shortVolNum;
  final double netVolNum;

  // Main Coins Data
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

  @override
  String toString() {
    return 'HyperData(open: $openPositionCount ($openPositionPct), profit: $profitCount, loss: $lossCount, sentiment: $sentiment)';
  }
}
