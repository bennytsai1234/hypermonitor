import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/data_model.dart';

class TrendChart extends StatelessWidget {
  final String title;
  final List<HyperData> fullHistory;
  final List<HyperData> displayHistory;
  final bool isBTC;
  final bool isETH;
  final bool isCombined;

  const TrendChart({
    super.key,
    required this.title,
    required this.fullHistory,
    required this.displayHistory,
    this.isBTC = false,
    this.isETH = false,
    this.isCombined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (displayHistory.length < 2) {
      return const Center(child: Text("等待數據累積...", style: TextStyle(color: Colors.white24, fontSize: 10)));
    }

    // Determine the sentiment of the LATEST data point
    final bool isBearish = displayHistory.last.sentiment.contains("跌");

    // DYNAMIC LOGIC:
    // If Bearish: We track (Short - Long). Upward line = More Short pressure.
    // If Bullish: We track (Long - Short). Upward line = More Long pressure.
    double getDynamicNet(HyperData d) {
      double l = 0.0;
      double s = 0.0;
      
      if (isCombined) {
        l = (d.btc?.longVol ?? 0) + (d.eth?.longVol ?? 0);
        s = (d.btc?.shortVol ?? 0) + (d.eth?.shortVol ?? 0);
      } else {
        final coin = isBTC ? d.btc : d.eth;
        l = coin?.longVol ?? 0;
        s = coin?.shortVol ?? 0;
      }
      
      return isBearish ? (s - l) : (l - s);
    }

    // Use the first point of the CURRENT display window as the 0-base for this hour
    // Calculated using the SAME dynamic formula to ensure the line starts at 0
    final double baseNet = getDynamicNet(displayHistory.first);
    final List<double> netSeries = displayHistory.map((e) => getDynamicNet(e) - baseNet).toList();

    double minV = netSeries.reduce((c, n) => c < n ? c : n);
    double maxV = netSeries.reduce((c, n) => c > n ? c : n);
    
    // Ensure zero line visibility and minimum scale
    if (minV > -100000) minV = -1000000;
    if (maxV < 100000) maxV = 1000000;
    
    double range = maxV - minV;
    double pad = range * 0.15;

    // Theme Color: Green for Long Strength (when Bullish), Red for Short Strength (when Bearish)
    // Actually, since upward always means "strengthening", we use the sentiment color.
    final Color themeColor = isBearish ? const Color(0xFFFF4949) : const Color(0xFF00C087);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      decoration: BoxDecoration(color: const Color(0xFF000000), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(
                  netSeries.last >= 0 ? (isBearish ? "淨空頭增長" : "淨多頭增長") : (isBearish ? "淨空頭萎縮" : "淨多頭萎縮"), 
                  style: TextStyle(color: themeColor.withAlpha(150), fontSize: 9, fontWeight: FontWeight.bold)
                ),
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
                  getDrawingHorizontalLine: (v) => FlLine(color: v.abs() < 1.0 ? Colors.white12 : Colors.white.withAlpha(2), strokeWidth: v.abs() < 1.0 ? 0.8 : 0.4),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 16, interval: 1,
                      getTitlesWidget: (v, m) {
                        int idx = v.toInt();
                        // Show time every 15 minutes (approx 90 points at 10s interval)
                        if (idx < 0 || idx >= displayHistory.length || idx % 90 != 0) return const SizedBox.shrink();
                        return Text(DateFormat('HH:mm').format(displayHistory[idx].timestamp), style: const TextStyle(color: Colors.white24, fontSize: 8));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, m) {
                        if (v == minV - pad || v == maxV + pad) return const SizedBox.shrink();
                        String sign = v > 0 ? "+" : "";
                        double absV = v.abs();
                        String t = absV >= 1e8 ? "$sign${(v / 1e8).toStringAsFixed(1)}B" : absV >= 1e4 ? "$sign${(v / 1e4).toStringAsFixed(0)}W" : v.toStringAsFixed(0);
                        return Text(t, style: TextStyle(color: Colors.white24.withAlpha(100), fontSize: 8), textAlign: TextAlign.right);
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
                        if (spot.barIndex != 0) return null;
                        final idx = spot.x.toInt();
                        if (idx < 0 || idx >= displayHistory.length) return null;
                        final d = displayHistory[idx];
                        final val = netSeries[idx];
                        
                        String fmt(double v) {
                          String s = v >= 0 ? "+" : "-";
                          double av = v.abs();
                          return s + (av >= 1e8 ? "${(av / 1e8).toStringAsFixed(2)}億" : "${(av / 1e4).toStringAsFixed(0)}萬");
                        }

                        final Color tipColor = val >= 0 ? const Color(0xFF00C087) : const Color(0xFFFF4949);

                        return LineTooltipItem(
                          "${DateFormat('HH:mm:ss').format(d.timestamp)}\n變動: ${fmt(val)}",
                          TextStyle(color: tipColor, fontSize: 10, fontWeight: FontWeight.bold)
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: minV - pad, maxY: maxV + pad,
                lineBarsData: [
                  LineChartBarData(
                    spots: netSeries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true, curveSmoothness: 0.1,
                    color: themeColor,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [themeColor.withAlpha(50), themeColor.withAlpha(0)],
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
}
