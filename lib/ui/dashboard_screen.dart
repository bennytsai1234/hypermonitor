import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/data_model.dart';
import '../core/data_scraper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  HyperData? _currentData;
  HyperData? _previousData;
  DateTime? _lastUpdate;
  bool _scraperReady = false; // Delay scraper to allow smooth loading animation

  // History for charts
  final List<HyperData> _history = [];
  final int _maxHistoryPoints = 300; // Keep last ~50 minutes (10s interval)

  @override
  void initState() {
    super.initState();
    // Delay scraper initialization to allow loading animation to run smoothly
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _scraperReady = true;
        });
      }
    });
  }

  void _handleNewData(HyperData newData) {
    if (_currentData != null) {
      if (_currentData!.walletCount != newData.walletCount ||
          _currentData!.netVolDisplay != newData.netVolDisplay ||
          _currentData!.longVolDisplay != newData.longVolDisplay ||
          _currentData!.shortVolDisplay != newData.shortVolDisplay) {
        _previousData = _currentData;
      }
    }

    setState(() {
      _currentData = newData;
      _lastUpdate = DateTime.now();

      // Add to history
      _history.add(newData);
      if (_history.length > _maxHistoryPoints) {
        _history.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Coinglass Theme Colors
    final bgDark = const Color(0xFF0D0E12);
    final cardBg = const Color(0xFF16171B);
    final textGreen = const Color(0xFF00C087);
    final textRed = const Color(0xFFFF4949);
    final textWhite = Colors.white;
    final textGrey = Colors.white54;

    // Dynamic focus based on sentiment
    final bool isBearish = _currentData?.sentiment.contains("跌") ?? false;
    final Color sentimentColor = _currentData != null ? _getSentimentColor(_currentData!.sentiment) : textGrey;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: const Text("Hyperliquid 實時監控儀表板"),
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Scraper (Hidden but isolated for performance)
          // Delayed initialization to allow loading animation to run smoothly
          if (_scraperReady)
            Positioned(
                bottom: 0,
                right: 0,
                width: 1,
                height: 1,
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: 0.0, // Hidden
                    child: CoinglassScraper(onDataScraped: _handleNewData),
                  ),
                ),
            ),

          // Main Content
          SafeArea(
            child: _currentData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF00C087)),
                      const SizedBox(height: 20),
                      Text("正在載入數據...", style: TextStyle(color: textGrey)),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // HEADER: All in one row
                      Row(
                        children: [
                          const Text(
                            "超級印鈔機",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "| 實時監控",
                            style: TextStyle(color: textGrey, fontSize: 12),
                          ),
                          const Spacer(),
                          if (_lastUpdate != null)
                            Text(
                              "${DateFormat('HH:mm:ss').format(_lastUpdate!)} ",
                              style: TextStyle(color: textGrey, fontSize: 10, fontFamily: 'monospace'),
                            ),
                          _buildSentimentBadge(_currentData!.sentiment),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ROW 1: PRIMARY FOCUS & KEY METRICS (Same as before)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildPrimaryCard(
                              isBearish: isBearish,
                              primaryLabel: isBearish ? "空單持倉" : "多單持倉",
                              primaryValue: isBearish ? _currentData!.shortVolDisplay : _currentData!.longVolDisplay,
                              primaryDelta: isBearish
                                  ? _calculateVolumeDelta(_previousData?.shortVolNum, _currentData!.shortVolNum)
                                  : _calculateVolumeDelta(_previousData?.longVolNum, _currentData!.longVolNum),
                              accentColor: sentimentColor,
                              cardBg: cardBg,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildMiniInfoCard(
                                  label: isBearish ? "BTC 空單" : "BTC 多單",
                                  value: (isBearish ? _currentData!.btc?.shortDisplay : _currentData!.btc?.longDisplay) ?? "---",
                                  delta: isBearish 
                                      ? _calculateVolumeDelta(_previousData?.btc?.shortVol, _currentData!.btc?.shortVol ?? 0.0)
                                      : _calculateVolumeDelta(_previousData?.btc?.longVol, _currentData!.btc?.longVol ?? 0.0),
                                  color: sentimentColor,
                                  cardBg: cardBg,
                                ),
                                const SizedBox(height: 8),
                                _buildMiniInfoCard(
                                  label: isBearish ? "ETH 空單" : "ETH 多單",
                                  value: (isBearish ? _currentData!.eth?.shortDisplay : _currentData!.eth?.longDisplay) ?? "---",
                                  delta: isBearish 
                                      ? _calculateVolumeDelta(_previousData?.eth?.shortVol, _currentData!.eth?.shortVol ?? 0.0)
                                      : _calculateVolumeDelta(_previousData?.eth?.longVol, _currentData!.eth?.longVol ?? 0.0),
                                  color: sentimentColor,
                                  cardBg: cardBg,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ROW 2 & 3: TUG OF WAR BARS
                      Row(
                        children: [
                          Expanded(
                            child: _buildTugOfWarBar(
                              label: "多空持倉對比",
                              leftVal: _currentData!.longVolNum,
                              rightVal: _currentData!.shortVolNum,
                              leftColor: textGreen,
                              rightColor: textRed,
                              leftLabel: "多頭",
                              rightLabel: "空頭",
                              cardBg: cardBg,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTugOfWarBar(
                              label: isBearish ? "空軍盈利中" : "多頭盈利中",
                              leftVal: _currentData!.profitCount.toDouble(),
                              rightVal: _currentData!.lossCount.toDouble(),
                              leftColor: textGreen,
                              rightColor: textRed,
                              leftLabel: "賺錢",
                              rightLabel: "虧錢",
                              isMirrored: true,
                              cardBg: cardBg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ROW 4: TRIPLE CHARTS (Side-by-Side)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _buildChartCard("總體持倉", _getRecentHistory(), isPrinter: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildChartCard("BTC 趨勢", _getRecentHistory(), isBTC: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildChartCard("ETH 趨勢", _getRecentHistory(), isETH: true)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  List<HyperData> _getRecentHistory() {
    // 10 mins = 600s. At 15s interval, that's 40 points.
    if (_history.length <= 40) return _history;
    return _history.sublist(_history.length - 40);
  }

  Widget _buildCoinRatioBar({
    required CoinPosition coin,
    required Color leftColor,
    required Color rightColor,
    required Color cardBg,
  }) {
    final total = coin.longVol + coin.shortVol;
    final leftPct = total > 0 ? (coin.longVol / total) : 0.5;
    final rightPct = 1.0 - leftPct;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(coin.symbol, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(
                "${(leftPct * 100).toStringAsFixed(0)}% : ${(rightPct * 100).toStringAsFixed(0)}%",
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(flex: (leftPct * 100).round().clamp(1, 99), child: Container(color: leftColor)),
                  const SizedBox(width: 1),
                  Expanded(flex: (rightPct * 100).round().clamp(1, 99), child: Container(color: rightColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(coin.longDisplay.replaceAll("亿", "億").replaceAll("万", "萬"), style: TextStyle(color: leftColor, fontSize: 8)),
              Text(coin.shortDisplay.replaceAll("亿", "億").replaceAll("万", "萬"), style: TextStyle(color: rightColor, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoCard({
    required String label,
    required String value,
    String? subValue,
    String? delta,
    required Color color,
    required Color cardBg,
  }) {
    Color deltaColor = Colors.grey;
    if (delta != null) {
      deltaColor = delta.startsWith('+') ? const Color(0xFF00C087) : const Color(0xFFFF4949);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              if (delta != null)
                Text(
                  delta,
                  style: TextStyle(color: deltaColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.replaceAll("亿", "億").replaceAll("万", "萬"),
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (subValue != null) ...[
                const SizedBox(width: 4),
                Text(subValue, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTugOfWarBar({
    required String label,
    required double leftVal,
    required double rightVal,
    required Color leftColor,
    required Color rightColor,
    required String leftLabel,
    required String rightLabel,
    bool isMirrored = false,
    required Color cardBg,
  }) {
    final total = leftVal + rightVal;
    final leftPct = total > 0 ? (leftVal / total) : 0.5;
    final rightPct = 1.0 - leftPct;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text(
                "${(leftPct * 100).toStringAsFixed(1)}% : ${(rightPct * 100).toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(flex: (leftPct * 1000).round(), child: Container(color: leftColor.withValues(alpha: 0.8))),
                      Expanded(flex: (rightPct * 1000).round(), child: Container(color: rightColor.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ),
              // Center Marker
              Container(width: 2, height: 16, color: Colors.white),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftLabel, style: TextStyle(color: leftColor, fontSize: 9, fontWeight: FontWeight.bold)),
              Text(rightLabel, style: TextStyle(color: rightColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCard({
    required bool isBearish,
    required String primaryLabel,
    required String primaryValue,
    String? primaryDelta,
    required Color accentColor,
    required Color cardBg,
  }) {
    Color deltaColor = Colors.grey;
    if (primaryDelta != null) {
      deltaColor = primaryDelta.startsWith('+') ? const Color(0xFF00C087) : const Color(0xFFFF4949);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            primaryLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            primaryValue,
            style: TextStyle(
              color: accentColor,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (primaryDelta != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                primaryDelta,
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    String? delta,
    String? subValue,
    required Color color,
    required Color cardBg,
    bool fullWidth = false,
  }) {
    Color deltaColor = Colors.grey;
    if (delta != null) {
      deltaColor = delta.startsWith('+') ? const Color(0xFF00C087) : const Color(0xFFFF4949);
    }

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (subValue != null) ...[
                const SizedBox(width: 4),
                Text(subValue, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(delta, style: TextStyle(color: deltaColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Color _getSentimentColor(String sentiment) {
    if (sentiment.contains("非常")) {
      return sentiment.contains("跌") ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
    } else if (sentiment.contains("略")) {
      return sentiment.contains("跌") ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7);
    } else if (sentiment.contains("看跌")) {
      return const Color(0xFFFF4949);
    } else if (sentiment.contains("看漲") || sentiment.contains("看漲")) {
      return const Color(0xFF00C087);
    }
    return Colors.grey; // 中性 / 猶豫不決
  }

  Widget _buildSentimentBadge(String sentiment) {
    final Color badgeColor = _getSentimentColor(sentiment);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Text(
        sentiment,
        style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildChartCard(String title, List<HyperData> history, {bool isPrinter = false, bool isBTC = false, bool isETH = false}) {
    if (history.length < 2) return const Center(child: Text("等待數據中...", style: TextStyle(color: Colors.white24, fontSize: 10)));

    final List<double> longSeries;
    final List<double> shortSeries;
    final Color longColor = const Color(0xFF00C087);
    final Color shortColor = const Color(0xFFFF4949);

    if (isPrinter) {
      longSeries = history.map((e) => e.longVolNum).toList();
      shortSeries = history.map((e) => e.shortVolNum).toList();
    } else if (isBTC) {
      longSeries = history.map((e) => e.btc?.longVol ?? 0.0).toList();
      shortSeries = history.map((e) => e.btc?.shortVol ?? 0.0).toList();
    } else {
      longSeries = history.map((e) => e.eth?.longVol ?? 0.0).toList();
      shortSeries = history.map((e) => e.eth?.shortVol ?? 0.0).toList();
    }

    final all = [...longSeries, ...shortSeries].where((v) => v > 0).toList();
    if (all.isEmpty) return const SizedBox.shrink();
    
    double minV = all.reduce((c, n) => c < n ? c : n);
    double maxV = all.reduce((c, n) => c > n ? c : n);
    double range = maxV - minV;
    double pad = range > 0 ? (range * 0.1) : 1000000;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF16171B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(
                  "10m 增量: ${isPrinter ? history.last.netVolDisplay : (isBTC ? history.last.btc?.totalDisplay ?? "" : history.last.eth?.totalDisplay ?? "")}",
                  style: const TextStyle(color: Colors.white24, fontSize: 8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: range > 0 ? range / 3 : null,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withAlpha(5), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 16,
                      interval: 10, 
                      getTitlesWidget: (v, m) {
                        int idx = v.toInt();
                        if (idx < 0 || idx >= history.length || idx % 10 != 0) return const SizedBox.shrink();
                        return Text(DateFormat('HH:mm').format(history[idx].timestamp), style: const TextStyle(color: Colors.white24, fontSize: 7));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, m) {
                        if (v == minV - pad || v == maxV + pad) return const SizedBox.shrink();
                        String t = v >= 1e8 ? "${(v / 1e8).toStringAsFixed(1)}B" : v >= 1e4 ? "${(v / 1e4).toStringAsFixed(0)}W" : v.toStringAsFixed(0);
                        return Text(t, style: const TextStyle(color: Colors.white24, fontSize: 7), textAlign: TextAlign.right);
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (s) => const Color(0xFF2E2F33),
                    getTooltipItems: (spots) {
                      if (spots.isEmpty) return [];
                      final idx = spots.first.x.toInt();
                      final data = history[idx];
                      String l = "", s = "";
                      if (isPrinter) { l = data.longVolDisplay; s = data.shortVolDisplay; }
                      else if (isBTC) { l = data.btc?.longDisplay ?? "-"; s = data.btc?.shortDisplay ?? "-"; }
                      else { l = data.eth?.longDisplay ?? "-"; s = data.eth?.shortDisplay ?? "-"; }
                      
                      return [
                        LineTooltipItem(
                          "${DateFormat('HH:mm:ss').format(data.timestamp)}\n多: $l\n空: $s",
                          const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        )
                      ];
                    },
                  ),
                ),
                minY: minV - pad,
                maxY: maxV + pad,
                lineBarsData: [
                  _chartLine(longSeries, longColor),
                  _chartLine(shortSeries, shortColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color.withAlpha(200), fontSize: 8, fontWeight: FontWeight.bold)),
      ],
    );
  }

  LineChartBarData _chartLine(List<double> spots, Color color) {
    return LineChartBarData(
      spots: spots.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: true,
      curveSmoothness: 0.1,
      color: color,
      barWidth: 1.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  String? _calculateIntDelta(int? prev, int curr) {
    if (prev == null) return null;
    final diff = curr - prev;
    if (diff == 0) return null;
    return diff > 0 ? "+$diff" : "$diff";
  }

  String? _calculateVolumeDelta(double? prev, double curr, {bool isShort = false}) {
    if (prev == null) return null;
    final diff = curr - prev;
    if (diff == 0) return null;

    String formatted;
    double absDiff = diff.abs();

    if (absDiff >= 100000000) {
      formatted = "\$${(absDiff / 100000000).toStringAsFixed(2)}億";
    } else if (absDiff >= 10000) {
      formatted = "\$${(absDiff / 10000).toStringAsFixed(2)}萬";
    } else {
       formatted = "\$${absDiff.toStringAsFixed(0)}";
    }

    // Logic:
    // If it's Long Volume: Increase (+, Green), Decrease (-, Red) -> Normal
    // If it's Short Volume: Increase (+, Red for bearish pressure), Decrease (-, Green for relief)
    // -> But user wants "加倉做空" (Increase Short) -> highlight RED
    // -> "減倉" (Decrease Short) -> highlight GREEN/NEUTRAL

    // Actually, user said: "空頭趨勢" -> "加倉做空" (Short Increase) -> He follows.
    // So visual indicator:
    // + Short (Red Text = Danger/Bearish Action)
    // - Short (Green Text = Bullish Action)

    // Standard Delta display:
    String sign = diff > 0 ? "+" : "-";
    return "$sign$formatted";
  }
}
