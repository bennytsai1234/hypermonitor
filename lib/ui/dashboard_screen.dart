import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _scraperReady = false;

  final List<HyperData> _history = [];
  final int _maxHistoryPoints = 360; // 60 minutes (10s interval)

  @override
  void initState() {
    super.initState();
    _loadHistory();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _scraperReady = true);
    });
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('scrape_history');
      if (data != null) {
        final List<dynamic> list = jsonDecode(data);
        setState(() {
          _history.clear();
          _history.addAll(list.map((e) => HyperData.fromJson(e)));
          if (_history.isNotEmpty) _currentData = _history.last;
        });
      }
    } catch (_) { }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_history.map((e) => e.toJson()).toList());
      await prefs.setString('scrape_history', data);
    } catch (_) { }
  }

  void _handleNewData(HyperData newData) {
    if (_currentData != null) {
      if (_currentData!.walletCount != newData.walletCount ||
          _currentData!.netVolDisplay != newData.netVolDisplay) {
        _previousData = _currentData;
      }
    }

    setState(() {
      _currentData = newData;
      _lastUpdate = DateTime.now();
      _history.add(newData);
      if (_history.length > _maxHistoryPoints) _history.removeAt(0);
    });
    _saveHistory();
  }

  @override
  Widget build(BuildContext context) {
    final bgDark = const Color(0xFF0D0E12);
    final cardBg = const Color(0xFF16171B);
    final textGreen = const Color(0xFF00C087);
    final textRed = const Color(0xFFFF4949);
    final textGrey = Colors.white54;

    final bool isBearish = _currentData?.sentiment.contains("跌") ?? false;
    final Color sentimentColor = _currentData != null ? _getSentimentColor(_currentData!.sentiment) : textGrey;

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          if (_scraperReady)
            Positioned(
                bottom: 0, right: 0, width: 1, height: 1,
                child: RepaintBoundary(
                  child: Opacity(
                    opacity: 0.0,
                    child: CoinglassScraper(onDataScraped: _handleNewData),
                  ),
                ),
            ),

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
                  padding: const EdgeInsets.all(12.0),
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

                      // ROW 1: 3-COLUMN METRICS (Overall, BTC, ETH)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Column 1: Overall
                          Expanded(
                            child: Column(
                              children: [
                                _buildMetricCard(
                                  label: isBearish ? "總體空單" : "總體多單",
                                  value: isBearish ? _currentData!.shortVolDisplay : _currentData!.longVolDisplay,
                                  delta: isBearish 
                                      ? _calculateVolumeDelta(_previousData?.shortVolNum, _currentData!.shortVolNum)
                                      : _calculateVolumeDelta(_previousData?.longVolNum, _currentData!.longVolNum),
                                  isShortDelta: isBearish,
                                  color: sentimentColor,
                                  cardBg: cardBg,
                                ),
                                const SizedBox(height: 8),
                                _buildMetricCard(
                                  label: isBearish ? "總淨空頭壓力" : "總淨多頭壓力",
                                  value: _calculateNetPressureStr(_currentData!, isBearish),
                                  delta: _calculateNetPressureDelta(_previousData, _currentData!, isBearish),
                                  isShortDelta: isBearish,
                                  color: sentimentColor,
                                  cardBg: cardBg,
                                  isSmall: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Column 2: BTC
                          Expanded(
                            child: Column(
                              children: [
                                _buildMetricCard(
                                  label: isBearish ? "BTC 空單" : "BTC 多單",
                                  value: (isBearish ? _currentData!.btc?.shortDisplay : _currentData!.btc?.longDisplay) ?? "---",
                                  delta: isBearish 
                                      ? _calculateVolumeDelta(_previousData?.btc?.shortVol, _currentData!.btc?.shortVol ?? 0.0)
                                      : _calculateVolumeDelta(_previousData?.btc?.longVol, _currentData!.btc?.longVol ?? 0.0),
                                  isShortDelta: isBearish,
                                  color: isBearish ? textRed : textGreen,
                                  cardBg: cardBg,
                                ),
                                const SizedBox(height: 8),
                                _buildMetricCard(
                                  label: isBearish ? "BTC 淨空壓" : "BTC 淨多壓",
                                  value: _calculateCoinNetStr(_currentData!.btc, isBearish),
                                  delta: _calculateCoinNetDelta(_previousData?.btc, _currentData!.btc, isBearish),
                                  isShortDelta: isBearish,
                                  color: isBearish ? textRed : textGreen,
                                  cardBg: cardBg,
                                  isSmall: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Column 3: ETH
                          Expanded(
                            child: Column(
                              children: [
                                _buildMetricCard(
                                  label: isBearish ? "ETH 空單" : "ETH 多單",
                                  value: (isBearish ? _currentData!.eth?.shortDisplay : _currentData!.eth?.longDisplay) ?? "---",
                                  delta: isBearish 
                                      ? _calculateVolumeDelta(_previousData?.eth?.shortVol, _currentData!.eth?.shortVol ?? 0.0)
                                      : _calculateVolumeDelta(_previousData?.eth?.longVol, _currentData!.eth?.longVol ?? 0.0),
                                  isShortDelta: isBearish,
                                  color: isBearish ? textRed : textGreen,
                                  cardBg: cardBg,
                                ),
                                const SizedBox(height: 8),
                                _buildMetricCard(
                                  label: isBearish ? "ETH 淨空壓" : "ETH 淨多壓",
                                  value: _calculateCoinNetStr(_currentData!.eth, isBearish),
                                  delta: _calculateCoinNetDelta(_previousData?.eth, _currentData!.eth, isBearish),
                                  isShortDelta: isBearish,
                                  color: isBearish ? textRed : textGreen,
                                  cardBg: cardBg,
                                  isSmall: true,
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
                            Expanded(child: _buildChartCard("總體 60m 變動", _history, isPrinter: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildChartCard("BTC 60m 變動", _history, isBTC: true)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildChartCard("ETH 60m 變動", _history, isETH: true)),
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

  // --- CALCULATION HELPERS ---

  String _calculateNetPressureStr(HyperData data, bool isBearish) {
    final double net = isBearish ? (data.shortVolNum - data.longVolNum) : (data.longVolNum - data.shortVolNum);
    return _formatVolume(net);
  }

  String? _calculateNetPressureDelta(HyperData? prev, HyperData curr, bool isBearish) {
    if (prev == null) return null;
    final double prevNet = isBearish ? (prev.shortVolNum - prev.longVolNum) : (prev.longVolNum - prev.shortVolNum);
    final double currNet = isBearish ? (curr.shortVolNum - curr.longVolNum) : (curr.longVolNum - curr.shortVolNum);
    return _calculateVolumeDelta(prevNet, currNet, isShortDelta: isBearish);
  }

  String _calculateCoinNetStr(CoinPosition? coin, bool isBearish) {
    if (coin == null) return "---";
    final double net = isBearish ? (coin.shortVol - coin.longVol) : (coin.longVol - coin.shortVol);
    return _formatVolume(net);
  }

  String? _calculateCoinNetDelta(CoinPosition? prev, CoinPosition? curr, bool isBearish) {
    if (prev == null || curr == null) return null;
    final double pNet = isBearish ? (prev.shortVol - prev.longVol) : (prev.longVol - prev.shortVol);
    final double cNet = isBearish ? (curr.shortVol - curr.longVol) : (curr.longVol - curr.shortVol);
    return _calculateVolumeDelta(pNet, cNet, isShortDelta: isBearish);
  }

  String _formatVolume(double v) {
    String sign = v >= 0 ? "+" : "";
    double absV = v.abs();
    if (absV >= 1e8) return "$sign\$${(v / 1e8).toStringAsFixed(2)}億";
    if (absV >= 1e4) return "$sign\$${(v / 1e4).toStringAsFixed(0)}萬";
    return "$sign\$${v.toStringAsFixed(0)}";
  }

  // --- UI COMPONENTS ---

  Widget _buildMetricCard({
    required String label,
    required String value,
    String? delta,
    bool isShortDelta = false,
    bool isSmall = false,
    required Color color,
    required Color cardBg,
  }) {
    Color deltaColor = Colors.grey;
    if (delta != null) {
      bool isPositive = delta.startsWith('+');
      deltaColor = isShortDelta 
          ? (isPositive ? const Color(0xFFFF4949) : const Color(0xFF00C087))
          : (isPositive ? const Color(0xFF00C087) : const Color(0xFFFF4949));
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 16, horizontal: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(isSmall ? 40 : 100), width: isSmall ? 1.0 : 1.5),
        boxShadow: [
          BoxShadow(color: color.withAlpha(isSmall ? 10 : 30), blurRadius: isSmall ? 6 : 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.white54, fontSize: isSmall ? 9 : 11)),
              if (delta != null)
                Text(delta, style: TextStyle(color: deltaColor, fontSize: isSmall ? 9 : 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.replaceAll("亿", "億").replaceAll("万", "萬"),
            style: TextStyle(
              color: color, 
              fontSize: isSmall ? 15 : 20, 
              fontWeight: isSmall ? FontWeight.bold : FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSentimentColor(String sentiment) {
    if (sentiment.contains("非常")) {
      return sentiment.contains("跌") ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
    } else if (sentiment.contains("略")) {
      return sentiment.contains("跌") ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7);
    } else if (sentiment.contains("跌")) {
      return const Color(0xFFFF4949);
    } else if (sentiment.contains("漲") || sentiment.contains("涨")) {
      return const Color(0xFF00C087);
    }
    return Colors.grey;
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
      child: Text(sentiment, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildTugOfWarBar({
    required String label, required double leftVal, required double rightVal,
    required Color leftColor, required Color rightColor, required String leftLabel,
    required String rightLabel, bool isMirrored = false, required Color cardBg,
  }) {
    final total = leftVal + rightVal;
    final leftPct = total > 0 ? (leftVal / total) : 0.5;
    final rightPct = 1.0 - leftPct;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              Text("${(leftPct * 100).toStringAsFixed(1)}% : ${(rightPct * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(flex: (leftPct * 1000).round(), child: Container(color: leftColor.withAlpha(200))),
                      Expanded(flex: (rightPct * 1000).round(), child: Container(color: rightColor.withAlpha(200))),
                    ],
                  ),
                ),
              ),
              Container(width: 1.5, height: 14, color: Colors.white),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftLabel, style: TextStyle(color: leftColor, fontSize: 8, fontWeight: FontWeight.bold)),
              Text(rightLabel, style: TextStyle(color: rightColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, List<HyperData> history, {bool isPrinter = false, bool isBTC = false, bool isETH = false}) {
    if (history.length < 2) return const Center(child: Text("等待數據累積...", style: TextStyle(color: Colors.white24, fontSize: 10)));

    final List<double> rawLong;
    final List<double> rawShort;
    
    if (isPrinter) {
      rawLong = history.map((e) => e.longVolNum).toList();
      rawShort = history.map((e) => e.shortVolNum).toList();
    } else if (isBTC) {
      rawLong = history.map((e) => e.btc?.longVol ?? 0.0).toList();
      rawShort = history.map((e) => e.btc?.shortVol ?? 0.0).toList();
    } else {
      rawLong = history.map((e) => e.eth?.longVol ?? 0.0).toList();
      rawShort = history.map((e) => e.eth?.shortVol ?? 0.0).toList();
    }

    final double baseLong = rawLong.first;
    final double baseShort = rawShort.first;
    final List<double> longSeries = rawLong.map((v) => v - baseLong).toList();
    final List<double> shortSeries = rawShort.map((v) => v - baseShort).toList();

    final all = [...longSeries, ...shortSeries];
    double minV = all.reduce((c, n) => c < n ? c : n);
    double maxV = all.reduce((c, n) => c > n ? c : n);
    if (minV > 0) minV = -1000000;
    if (maxV < 0) maxV = 1000000;
    double range = maxV - minV;
    double pad = range > 0 ? (range * 0.15) : 1000000;

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      decoration: BoxDecoration(color: const Color(0xFF16171B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                Wrap(spacing: 6, children: [_buildLegend("多", const Color(0xFF00C087)), _buildLegend("空", const Color(0xFFFF4949))]),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true, drawVerticalLine: false,
                  horizontalInterval: range > 0 ? range / 4 : null,
                  getDrawingHorizontalLine: (v) => FlLine(color: v.abs() < 1.0 ? Colors.white24 : Colors.white.withAlpha(5), strokeWidth: v.abs() < 1.0 ? 1 : 0.5),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 16, interval: (history.length / 4).clamp(1.0, 100.0),
                      getTitlesWidget: (v, m) {
                        int idx = v.toInt();
                        if (idx < 0 || idx >= history.length || idx % 20 != 0) return const SizedBox.shrink();
                        return Text(DateFormat('HH:mm').format(history[idx].timestamp), style: const TextStyle(color: Colors.white24, fontSize: 7));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 40,
                      getTitlesWidget: (v, m) {
                        if (v == minV - pad || v == maxV + pad) return const SizedBox.shrink();
                        String sign = v > 0 ? "+" : "";
                        double absV = v.abs();
                        String t = absV >= 1e8 ? "$sign${(v / 1e8).toStringAsFixed(1)}B" : absV >= 1e4 ? "$sign${(v / 1e4).toStringAsFixed(0)}W" : v.toStringAsFixed(0);
                        return Text(t, style: TextStyle(color: v >= 0 ? const Color(0xFF00C087).withAlpha(100) : const Color(0xFFFF4949).withAlpha(100), fontSize: 7), textAlign: TextAlign.right);
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (s) => const Color(0xFF2E2F33),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        // Only show the tooltip for the first line (barIndex 0) to prevent duplicates
                        if (spot.barIndex != 0) return null;

                        final idx = spot.x.toInt();
                        if (idx < 0 || idx >= history.length) return null;
                        
                        final data = history[idx];
                        String l = "", s = "";
                        double curL = 0, curS = 0;
                        if (isPrinter) { 
                          l = data.longVolDisplay; s = data.shortVolDisplay; curL = data.longVolNum - baseLong; curS = data.shortVolNum - baseShort;
                        } else if (isBTC) { 
                          l = data.btc?.longDisplay ?? "-"; s = data.btc?.shortDisplay ?? "-"; curL = (data.btc?.longVol ?? 0) - baseLong; curS = (data.btc?.shortVol ?? 0) - baseShort;
                        } else { 
                          l = data.eth?.longDisplay ?? "-"; s = data.eth?.shortDisplay ?? "-"; curL = (data.eth?.longVol ?? 0) - baseLong; curS = (data.eth?.shortVol ?? 0) - baseShort;
                        }
                        String fmt(double v) => (v >= 0 ? "+" : "") + (v.abs() >= 1e8 ? "${(v / 1e8).toStringAsFixed(2)}億" : "${(v / 1e4).toStringAsFixed(0)}萬");
                        
                        return LineTooltipItem(
                          "${DateFormat('HH:mm:ss').format(data.timestamp)}\n多: $l (${fmt(curL)})\n空: $s (${fmt(curS)})",
                          const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: minV - pad, maxY: maxV + pad,
                lineBarsData: [_chartLine(longSeries, const Color(0xFF00C087)), _chartLine(shortSeries, const Color(0xFFFF4949))],
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
      isCurved: true, curveSmoothness: 0.1, color: color, barWidth: 1.5,
      dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: false),
    );
  }

  String? _calculateVolumeDelta(double? prev, double curr, {bool isShortDelta = false}) {
    if (prev == null) return null;
    final diff = curr - prev;
    if (diff == 0) return null;
    double absDiff = diff.abs();
    String formatted = absDiff >= 1e8 ? "${(absDiff / 1e8).toStringAsFixed(2)}億" : "${(absDiff / 1e4).toStringAsFixed(0)}萬";
    return (diff > 0 ? "+" : "-") + "\$" + formatted;
  }
}