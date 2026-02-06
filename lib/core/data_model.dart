class HyperData {
  final DateTime timestamp;
  final int walletCount;
  final String longVolDisplay;
  final String shortVolDisplay;
  final String netVolDisplay; // This might be total open interest or net

  // Numeric values for calculation
  final double longVolNum;
  final double shortVolNum;
  final double netVolNum;

  HyperData({
    required this.timestamp,
    required this.walletCount,
    required this.longVolDisplay,
    required this.shortVolDisplay,
    required this.netVolDisplay,
    required this.longVolNum,
    required this.shortVolNum,
    required this.netVolNum,
  });

  @override
  String toString() {
    return 'HyperData(wallets: $walletCount, long: $longVolDisplay, short: $shortVolDisplay)';
  }
}
