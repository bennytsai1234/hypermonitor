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
                      // HEADER: Title + Sentiment + Update Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "超级印钞机",
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              if (_lastUpdate != null)
                                Text(
                                  "更新於 ${DateFormat('HH:mm:ss').format(_lastUpdate!)}",
                                  style: TextStyle(color: textGrey, fontSize: 10),
                                ),
                            ],
                          ),
                          _buildSentimentBadge(_currentData!.sentiment),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ROW 1: PRIMARY FOCUS & KEY METRICS
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
                              accentColor: isBearish ? textRed : textGreen,
                              cardBg: cardBg,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildMiniInfoCard(
                                  label: "開倉",
                                  value: "${_currentData!.openPositionCount}",
                                  subValue: _currentData!.openPositionPct,
                                  color: Colors.amber,
                                  cardBg: cardBg,
                                ),
                                const SizedBox(height: 8),
                                _buildMiniInfoCard(
                                  label: "淨持倉",
                                  value: _currentData!.netVolDisplay,
                                  color: Colors.blueAccent,
                                  cardBg: cardBg,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ROW 2: TUG OF WAR (VOLUME RATIO)
                      _buildTugOfWarBar(
                        label: "多空持倉實力對比 (Volume)",
                        leftVal: _currentData!.longVolNum,
                        rightVal: _currentData!.shortVolNum,
                        leftColor: textGreen,
                        rightColor: textRed,
                        leftLabel: "多頭",
                        rightLabel: "空頭",
                        cardBg: cardBg,
                      ),
                      const SizedBox(height: 8),

                      // ROW 3: PROFIT/LOSS RATIO (WINNERS VS LOSERS)
                      _buildTugOfWarBar(
                        label: isBearish ? "當前優勢：空軍盈利中" : "當前優勢：多頭盈利中",
                        leftVal: _currentData!.profitCount.toDouble(),
                        rightVal: _currentData!.lossCount.toDouble(),
                        leftColor: textGreen,
                        rightColor: textRed,
                        leftLabel: "賺錢",
                        rightLabel: "虧錢",
                        isMirrored: true, // Specific look for P/L
                        cardBg: cardBg,
                      ),
                      const SizedBox(height: 12),

                      // ROW 3.5: BTC & ETH Details
                      if (_currentData!.btc != null || _currentData!.eth != null) ...[
                        Row(
                          children: [
                            if (_currentData!.btc != null)
                              Expanded(
                                child: _buildCoinRatioBar(
                                  coin: _currentData!.btc!,
                                  leftColor: textGreen,
                                  rightColor: textRed,
                                  cardBg: cardBg,
                                ),
                              ),
                            if (_currentData!.btc != null && _currentData!.eth != null)
                              const SizedBox(width: 8),
                            if (_currentData!.eth != null)
                              Expanded(
                                child: _buildCoinRatioBar(
                                  coin: _currentData!.eth!,
                                  leftColor: textGreen,
                                  rightColor: textRed,
                                  cardBg: cardBg,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ROW 4: CHART (STRETCHED)
                      Expanded(
                        child: _buildChartCard(
                          isBearish ? "空單趨勢" : "多單趨勢",
                          _history,
                          isBearish ? textRed : textGreen,
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
    required Color color,
    required Color cardBg,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildSentimentBadge(String sentiment) {
    Color badgeColor = Colors.grey;
    if (sentiment.contains("跌")) badgeColor = const Color(0xFFFF4949);
    if (sentiment.contains("漲")) badgeColor = const Color(0xFF00C087);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        sentiment,
        style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChartCard(String title, List<HyperData> history, Color lineColor) {
    if (history.length < 2) return const SizedBox.shrink();

    final bool isBearish = _currentData?.sentiment.contains("跌") ?? false;
    final dataPoints = isBearish 
        ? history.map((e) => e.shortVolNum).toList() 
        : history.map((e) => e.longVolNum).toList();

    double minVal = dataPoints.reduce((curr, next) => curr < next ? curr : next);
    double maxVal = dataPoints.reduce((curr, next) => curr > next ? curr : next);

    // Dynamic padding: If the range is very small, use tighter padding to show movement
    double range = maxVal - minVal;
    final double padding = range > 0 ? (range * 0.2) : 1000000; 
    
    double chartMin = minVal - padding;
    double chartMax = maxVal + padding;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 16, 12, 8), // Tighter padding for dashboard
      decoration: BoxDecoration(
        color: const Color(0xFF16171B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: lineColor, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  "增量監控中",
                  style: TextStyle(color: lineColor.withValues(alpha: 0.5), fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: range > 0 ? range / 3 : null,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.03),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (history.length / 3).clamp(1.0, 500.0),
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= history.length) return const SizedBox.shrink();
                        return Text(
                          DateFormat('HH:mm').format(history[index].timestamp),
                          style: const TextStyle(color: Colors.white24, fontSize: 9),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55, // Increased for labels like 14.12B
                      getTitlesWidget: (value, meta) {
                        if (value == chartMin || value == chartMax) return const SizedBox.shrink();
                        String text = "";
                        if (value >= 100000000 || value <= -100000000) {
                          text = "${(value / 100000000).toStringAsFixed(2)}B";
                        } else if (value >= 10000 || value <= -10000) {
                          text = "${(value / 10000).toStringAsFixed(0)}W";
                        } else {
                          text = value.toStringAsFixed(0);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(text, style: const TextStyle(color: Colors.white24, fontSize: 9), textAlign: TextAlign.right),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF2E2F33),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final data = history[index];
                        String vol = isBearish ? data.shortVolDisplay : data.longVolDisplay;
                        
                        // Calculate Delta from previous point
                        String deltaText = "";
                        if (index > 0) {
                          final prev = history[index - 1];
                          final currentVal = isBearish ? data.shortVolNum : data.longVolNum;
                          final prevVal = isBearish ? prev.shortVolNum : prev.longVolNum;
                          final diff = currentVal - prevVal;
                          if (diff != 0) {
                            String sign = diff > 0 ? "+" : "";
                            String formattedDiff;
                            double absDiff = diff.abs();
                            if (absDiff >= 100000000) formattedDiff = "${(diff / 100000000).toStringAsFixed(2)}亿";
                            else if (absDiff >= 10000) formattedDiff = "${(diff / 10000).toStringAsFixed(1)}万";
                            else formattedDiff = diff.toStringAsFixed(0);
                            deltaText = "\n$sign$formattedDiff";
                          }
                        }

                        return LineTooltipItem(
                          "${DateFormat('HH:mm:ss').format(data.timestamp)}\n$vol$deltaText",
                          TextStyle(
                            color: lineColor, 
                            fontSize: 11, 
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: chartMin,
                maxY: chartMax,
                lineBarsData: [
                  LineChartBarData(
                    spots: dataPoints.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: lineColor,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    // Enable dots for each data point
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 2,
                        color: lineColor,
                        strokeWidth: 1,
                        strokeColor: Colors.black,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          lineColor.withValues(alpha: 0.15),
                          lineColor.withValues(alpha: 0.0),
                        ],
                      ),
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
