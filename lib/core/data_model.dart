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
    longVol: (j['long_vol'] ?? j['longVol'] ?? 0.0).toDouble(),
    shortVol: (j['short_vol'] ?? j['shortVol'] ?? 0.0).toDouble(),
    totalVol: (j['total_vol'] ?? j['totalVol'] ?? 0.0).toDouble(),
    netVol: (j['net_vol'] ?? j['netVol'] ?? 0.0).toDouble(),
    longDisplay: j['long_display'] ?? j['longDisplay'] ?? "",
    shortDisplay: j['short_display'] ?? j['shortDisplay'] ?? "",
    totalDisplay: j['total_display'] ?? j['totalDisplay'] ?? "",
    netDisplay: j['net_display'] ?? j['netDisplay'] ?? "",
  );
}

extension TaiwanTime on DateTime {
  DateTime toTaiwanTime() {
    // 1. 先取得該時間點的 UTC 物件
    final utcTime = toUtc();
    // 2. 加上 8 小時得到臺灣數值
    final twValue = utcTime.add(const Duration(hours: 8));
    // 3. 關鍵：回傳一個「數值與臺灣同步」但「標記為本地」的時間物件
    // 這樣 UI 格式化工具就不會再根據系統時區去做額外轉換
    return DateTime(
      twValue.year,
      twValue.month,
      twValue.day,
      twValue.hour,
      twValue.minute,
      twValue.second,
      twValue.millisecond,
    );
  }
}

class HyperData {
  final DateTime timestamp;
  final int walletCount;
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

  factory HyperData.fromJson(Map<String, dynamic> j) {
    String ts = j['timestamp'] ?? DateTime.now().toIso8601String();
    if (!ts.contains('T')) ts = ts.replaceFirst(' ', 'T');
    
    // 如果伺服器傳回的字串沒有時區資訊，強制加上 Z (UTC)，避免被誤判為本地時間
    if (!ts.endsWith('Z') && !ts.contains(RegExp(r'[+-]\d{2}:?\d{2}'))) {
      ts += 'Z';
    }

    return HyperData(
      timestamp: DateTime.parse(ts).toTaiwanTime(),
      walletCount: (j['wallet_count'] ?? j['walletCount'] ?? 0).toInt(),
      profitCount: (j['profit_count'] ?? j['profitCount'] ?? 0).toInt(),
      lossCount: (j['loss_count'] ?? j['lossCount'] ?? 0).toInt(),
      longVolDisplay: j['long_display'] ?? j['longVolDisplay'] ?? "",
      shortVolDisplay: j['short_display'] ?? j['shortVolDisplay'] ?? "",
      netVolDisplay: j['net_display'] ?? j['netVolDisplay'] ?? "",
      sentiment: j['sentiment'] ?? "",
      longVolNum: (j['long_vol_num'] ?? j['longVolNum'] ?? 0.0).toDouble(),
      shortVolNum: (j['short_vol_num'] ?? j['shortVolNum'] ?? 0.0).toDouble(),
      netVolNum: (j['net_vol_num'] ?? j['netVolNum'] ?? 0.0).toDouble(),
      btc: j['btc'] != null ? CoinPosition.fromJson(j['btc']) : null,
      eth: j['eth'] != null ? CoinPosition.fromJson(j['eth']) : null,
    );
  }
}
