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

    final bool isBearish = displayHistory.last.sentiment.contains("跌");

    // DYNAMIC SAMPLING: If we have > 1000 points, take every 6th point (1 min intervals)
    final bool useSampling = displayHistory.length > 1000;
    final List<HyperData> sampledHistory = [];
    if (useSampling) {
      for (int i = 0; i < displayHistory.length; i += 6) {
        sampledHistory.add(displayHistory[i]);
      }
      if ((displayHistory.length - 1) % 6 != 0) sampledHistory.add(displayHistory.last);
    } else {
      sampledHistory.addAll(displayHistory);
    }

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

    final double baseNet = getDynamicNet(sampledHistory.first);
    final List<double> netSeries = sampledHistory.map((e) => getDynamicNet(e) - baseNet).toList();

    double minV = netSeries.reduce((c, n) => c < n ? c : n);
    double maxV = netSeries.reduce((c, n) => c > n ? c : n);
    
    if (minV > -100000) minV = -1000000;
    if (maxV < 100000) maxV = 1000000;
    
    double range = maxV - minV;
    double pad = range * 0.15;

    final Color themeColor = isBearish ? const Color(0xFFFF4949) : const Color(0xFF00C087);
    final double vInterval = useSampling ? 240.0 : 90.0; // 4h vs 15m

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: themeColor.withAlpha(80), width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(
                  netSeries.last >= 0 ? (isBearish ? "空頭佔優" : "多頭佔優") : (isBearish ? "空頭減弱" : "多頭減弱"),
                  style: TextStyle(color: themeColor.withAlpha(200), fontSize: 9, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  verticalInterval: vInterval,
                  horizontalInterval: range > 0 ? range / 4 : null,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withAlpha(10), strokeWidth: 0.5),
                  getDrawingVerticalLine: (v) => FlLine(color: Colors.white.withAlpha(10), strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      getTitlesWidget: (v, m) {
                        int idx = v.toInt();
                        if (idx < 0 || idx >= sampledHistory.length || idx % vInterval != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(DateFormat('HH:mm').format(sampledHistory[idx].timestamp), style: const TextStyle(color: Colors.white30, fontSize: 8)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (v, m) {
                        if (v == minV - pad || v == maxV + pad) return const SizedBox.shrink();
                        String sign = v > 0 ? "+" : "";
                        double absV = v.abs();
                        String t = absV >= 1e8 ? "$sign${(v / 1e8).toStringAsFixed(1)}B" : absV >= 1e4 ? "$sign${(v / 1e4).toStringAsFixed(0)}W" : v.toStringAsFixed(0);
                        return Text(t, style: const TextStyle(color: Colors.white24, fontSize: 8), textAlign: TextAlign.right);
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (s) => const Color(0xFF1A1A1A),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        if (spot.barIndex != 0) return null;
                        final idx = spot.x.toInt();
                        if (idx < 0 || idx >= sampledHistory.length) return null;
                        final d = sampledHistory[idx];
                        final val = netSeries[idx];
                        String fmt(double v) {
                          String s = v >= 0 ? "+" : "-";
                          double av = v.abs();
                          return s + (av >= 1e8 ? "${(av / 1e8).toStringAsFixed(2)}億" : "${(av / 1e4).toStringAsFixed(0)}萬");
                        }
                        return LineTooltipItem(
                          "${DateFormat('HH:mm:ss').format(d.timestamp)}\n變動: ${fmt(val)}",
                          TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold)
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: minV - pad,
                maxY: maxV + pad,
                lineBarsData: [
                  LineChartBarData(
                    spots: netSeries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: !useSampling,
                    curveSmoothness: 0.05,
                    color: themeColor,
                    barWidth: useSampling ? 1.0 : 1.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [themeColor.withAlpha(40), themeColor.withAlpha(0)],
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