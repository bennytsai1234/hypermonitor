class HyperFormatter {
  static String format(double val) {
    if (val == 0) return "--";
    final abs = val.abs();
    if (abs >= 100000000) {
      return "${(val / 100000000).toStringAsFixed(2)}億";
    } else if (abs >= 10000) {
      return "${(val / 10000).toStringAsFixed(0)}萬";
    }
    return val.toStringAsFixed(0);
  }

  // Format with explicit sign (+) for positive values
  static String formatNet(double val) {
    if (val == 0) return "--";
    final prefix = val > 0 ? "+" : "";
    return "$prefix${format(val)}";
  }
}

class CoinPosition {
  final String symbol;
  final double longVol;
  final double shortVol;
  final double totalVol;
  final double netVol;

  CoinPosition({
    required this.symbol,
    required this.longVol,
    required this.shortVol,
    required this.totalVol,
    required this.netVol,
  });

  String get longDisplay => HyperFormatter.format(longVol);
  String get shortDisplay => HyperFormatter.format(shortVol);
  String get totalDisplay => HyperFormatter.format(totalVol);
  String get netDisplay => HyperFormatter.formatNet(netVol);

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'longVol': longVol,
    'shortVol': shortVol,
    'totalVol': totalVol,
    'netVol': netVol,
  };

  factory CoinPosition.fromJson(Map<String, dynamic> j) => CoinPosition(
    symbol: j['symbol'] ?? "",
    longVol: (j['long_vol'] ?? j['longVol'] ?? 0.0).toDouble(),
    shortVol: (j['short_vol'] ?? j['shortVol'] ?? 0.0).toDouble(),
    totalVol: (j['total_vol'] ?? j['totalVol'] ?? 0.0).toDouble(),
    netVol: (j['net_vol'] ?? j['netVol'] ?? 0.0).toDouble(),
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
  // Super Money Printer
  final int walletCount;
  final int profitCount;
  final int lossCount;
  final String sentiment;
  final double longVolNum;
  final double shortVolNum;
  final double netVolNum;

  // Smart Money ($10w - $100w)
  final int? smartWalletCount;
  final int? smartProfitCount;
  final int? smartLossCount;
  final String? smartSentiment;
  final double? smartLongVolNum;
  final double? smartShortVolNum;
  final double? smartNetVolNum;

  final CoinPosition? btc;
  final CoinPosition? eth;

  HyperData({
    required this.timestamp,
    required this.walletCount,
    required this.profitCount,
    required this.lossCount,
    required this.sentiment,
    required this.longVolNum,
    required this.shortVolNum,
    required this.netVolNum,
    this.smartWalletCount,
    this.smartProfitCount,
    this.smartLossCount,
    this.smartSentiment,
    this.smartLongVolNum,
    this.smartShortVolNum,
    this.smartNetVolNum,
    this.btc,
    this.eth,
  });

  String get longVolDisplay => HyperFormatter.format(longVolNum);
  String get shortVolDisplay => HyperFormatter.format(shortVolNum);
  String get netVolDisplay => HyperFormatter.formatNet(netVolNum);

  String? get smartLongVolDisplay => smartLongVolNum != null ? HyperFormatter.format(smartLongVolNum!) : null;
  String? get smartShortVolDisplay => smartShortVolNum != null ? HyperFormatter.format(smartShortVolNum!) : null;
  String? get smartNetVolDisplay => smartNetVolNum != null ? HyperFormatter.formatNet(smartNetVolNum!) : null;

  factory HyperData.fromJson(Map<String, dynamic> j) {
    String ts = j['timestamp'] ?? DateTime.now().toIso8601String();
    if (!ts.contains('T')) ts = ts.replaceFirst(' ', 'T');

    if (!ts.endsWith('Z') && !ts.contains(RegExp(r'[+-]\d{2}:?\d{2}'))) {
      ts += 'Z';
    }

    // Extract Smart Money data if present (either from j['smart'] or prefix fields)
    final s = j['smart'] ?? {};

    return HyperData(
      timestamp: DateTime.parse(ts).toTaiwanTime(),
      walletCount: (j['wallet_count'] ?? j['walletCount'] ?? 0).toInt(),
      profitCount: (j['profit_count'] ?? j['profitCount'] ?? 0).toInt(),
      lossCount: (j['loss_count'] ?? j['lossCount'] ?? 0).toInt(),
      sentiment: j['sentiment'] ?? "",
      longVolNum: (j['long_vol_num'] ?? j['longVolNum'] ?? 0.0).toDouble(),
      shortVolNum: (j['short_vol_num'] ?? j['shortVolNum'] ?? 0.0).toDouble(),
      netVolNum: (j['net_vol_num'] ?? j['netVolNum'] ?? 0.0).toDouble(),

      // Smart Money mapping
      smartWalletCount: (s['walletCount'] ?? j['smart_wallet_count'] ?? 0).toInt(),
      smartProfitCount: (s['profitCount'] ?? j['smart_profit_count'] ?? 0).toInt(),
      smartLossCount: (s['lossCount'] ?? j['smart_loss_count'] ?? 0).toInt(),
      smartSentiment: s['sentiment'] ?? j['smart_sentiment'] ?? "",
      smartLongVolNum: (s['longVolNum'] ?? j['smart_long_vol_num'] ?? 0.0).toDouble(),
      smartShortVolNum: (s['short_vol_num'] ?? j['smart_short_vol_num'] ?? 0.0).toDouble(),
      smartNetVolNum: (s['net_vol_num'] ?? j['smart_net_vol_num'] ?? 0.0).toDouble(),

      btc: j['btc'] != null ? CoinPosition.fromJson(j['btc']) : null,
      eth: j['eth'] != null ? CoinPosition.fromJson(j['eth']) : null,
    );
  }
}
