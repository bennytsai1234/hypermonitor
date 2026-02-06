import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/data_model.dart';
import '../core/data_scraper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  HyperData? _currentData;
  HyperData? _previousData;
  DateTime? _lastUpdate;

  // History for charts
  final List<HyperData> _history = [];
  final int _maxHistoryPoints = 100; // Keep last ~8-10 minutes (5s interval)

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
        title: const Text("Hyperliquid Monitor"),
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Scraper (Hidden in production)
          Positioned(
              bottom: 0,
              right: 0,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0.0, // Hidden
                child: CoinglassScraper(onDataScraped: _handleNewData),
              ),
          ),

          // Main Content
          Center(
            child: _currentData == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00C087)),
                    const SizedBox(height: 20),
                    Text("正在載入數據...", style: TextStyle(color: textGrey)),
                  ],
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Title and Sentiment Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "超级印钞机",
                              style: TextStyle(
                                color: textWhite,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildSentimentBadge(_currentData!.sentiment),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isBearish ? "趨勢看跌・關注空單" : "趨勢看漲・關注多單",
                          style: TextStyle(color: textGrey, fontSize: 14),
                        ),
                        const SizedBox(height: 24),

                        // PRIMARY FOCUS CARD (Dynamic: Short or Long based on sentiment)
                        _buildPrimaryCard(
                          isBearish: isBearish,
                          primaryLabel: isBearish ? "空單持倉" : "多單持倉",
                          primaryValue: isBearish ? _currentData!.shortVolDisplay : _currentData!.longVolDisplay,
                          primaryDelta: isBearish
                              ? _calculateVolumeDelta(_previousData?.shortVolNum, _currentData!.shortVolNum)
                              : _calculateVolumeDelta(_previousData?.longVolNum, _currentData!.longVolNum),
                          accentColor: isBearish ? textRed : textGreen,
                          cardBg: cardBg,
                        ),
                        const SizedBox(height: 16),

                        // SECONDARY INFO ROW
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                label: isBearish ? "多單持倉" : "空單持倉",
                                value: isBearish ? _currentData!.longVolDisplay : _currentData!.shortVolDisplay,
                                delta: isBearish
                                    ? _calculateVolumeDelta(_previousData?.longVolNum, _currentData!.longVolNum)
                                    : _calculateVolumeDelta(_previousData?.shortVolNum, _currentData!.shortVolNum),
                                color: isBearish ? textGreen : textRed,
                                cardBg: cardBg,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                label: "錢包數",
                                value: "${_currentData!.walletCount}",
                                delta: _calculateIntDelta(_previousData?.walletCount, _currentData!.walletCount),
                                color: textWhite,
                                cardBg: cardBg,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // NET VOLUME
                        _buildInfoCard(
                          label: "淨持倉",
                          value: _currentData!.netVolDisplay,
                          delta: _calculateVolumeDelta(_previousData?.netVolNum, _currentData!.netVolNum),
                          color: Colors.blueAccent,
                          cardBg: cardBg,
                          fullWidth: true,
                        ),
                        const SizedBox(height: 20),

                        // Last Updated
                        if (_lastUpdate != null)
                          Text(
                            "更新於 ${DateFormat('HH:mm:ss').format(_lastUpdate!)}",
                            style: TextStyle(color: textGrey, fontSize: 12),
                          ),
                        const SizedBox(height: 20),

                        // Chart (Only for the primary focus)
                        if (_history.length > 2)
                          _buildChartCard(
                            isBearish ? "空單趨勢" : "多單趨勢",
                            isBearish
                                ? _history.map((e) => e.shortVolNum).toList()
                                : _history.map((e) => e.longVolNum).toList(),
                            isBearish ? textRed : textGreen,
                          ),
                      ],
                    ),
                  ),
                ),
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
        border: Border.all(color: accentColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            primaryLabel,
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
                color: deltaColor.withOpacity(0.15),
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
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(delta, style: TextStyle(color: deltaColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(Color accent) {
    return Column(
      children: [
        Icon(Icons.monitor_heart_outlined, size: 50, color: accent),
        const SizedBox(height: 10),
        const Text(
          "Smart Money Tracker",
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSentimentBadge(String sentiment) {
    Color badgeColor = Colors.grey;
    if (sentiment.contains("跌")) badgeColor = const Color(0xFFFF4949);
    if (sentiment.contains("涨")) badgeColor = const Color(0xFF00C087);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        sentiment,
        style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRowItem(String label, String value, {String? delta, Color? valueColor, String? subValue, bool isHighlighted = false}) {
     Color deltaColor = Colors.grey;
     if (delta != null) {
       if (delta.startsWith('+')) deltaColor = const Color(0xFF00C087); // Increase green
       else deltaColor = const Color(0xFFFF4949); // Decrease red
     }

     return Container(
       padding: isHighlighted ? const EdgeInsets.symmetric(vertical: 8, horizontal: 4) : EdgeInsets.zero,
       decoration: isHighlighted ? BoxDecoration(
         color: Colors.white.withOpacity(0.05),
         borderRadius: BorderRadius.circular(8),
       ) : null,
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
               if (subValue != null)
                  Text(subValue, style: const TextStyle(color: Colors.white30, fontSize: 12)),
             ],
           ),
           Column(
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
               Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
               if (delta != null)
                 Text(delta, style: TextStyle(
                   color: deltaColor,
                   fontSize: 14,
                   fontWeight: FontWeight.bold
                 )),
             ],
           )
         ],
       ),
     );
  }

  Widget _buildChartCard(String title, List<double> dataPoints, Color lineColor) {
     if (dataPoints.isEmpty) return const SizedBox.shrink();

     double minVal = dataPoints.reduce((curr, next) => curr < next ? curr : next);
     double maxVal = dataPoints.reduce((curr, next) => curr > next ? curr : next);

     // Add output padding
     final double padding = (maxVal - minVal) * 0.1;
     double chartMin, chartMax;

     if (padding == 0) { // Flat line
         chartMin = minVal - 1000;
         chartMax = maxVal + 1000;
     } else {
         chartMin = minVal - padding;
         chartMax = maxVal + padding;
     }

     return Container(
       height: 150,
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: const Color(0xFF16171B).withOpacity(0.95), // Consistent opactiy
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: Colors.white10),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(title, style: TextStyle(color: lineColor, fontWeight: FontWeight.bold, fontSize: 14)),
           const SizedBox(height: 10),
           Expanded(
             child: LineChart(
               LineChartData(
                 gridData: FlGridData(show: false),
                 titlesData: FlTitlesData(show: false),
                 borderData: FlBorderData(show: false),
                 lineTouchData: LineTouchData(enabled: false), // Disable touch for performance
                 minY: chartMin,
                 maxY: chartMax,
                 lineBarsData: [
                   LineChartBarData(
                     spots: dataPoints.asMap().entries.map((e) {
                       return FlSpot(e.key.toDouble(), e.value);
                     }).toList(),
                     isCurved: true,
                     color: lineColor,
                     barWidth: 2,
                     isStrokeCapRound: true,
                     dotData: FlDotData(show: false),
                     belowBarData: BarAreaData(
                       show: true,
                       color: lineColor.withOpacity(0.1),
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
      formatted = "\$${(absDiff / 100000000).toStringAsFixed(2)}亿";
    } else if (absDiff >= 10000) {
      formatted = "\$${(absDiff / 10000).toStringAsFixed(2)}万";
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
