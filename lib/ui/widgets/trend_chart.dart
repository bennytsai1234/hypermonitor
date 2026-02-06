import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/data_model.dart';

class TrendChart extends StatelessWidget {
  final String title;
  final List<HyperData> history;
  final bool isPrinter;
  final bool isBTC;
  final bool isETH;

  const TrendChart({
    super.key,
    required this.title,
    required this.history,
    this.isPrinter = false,
    this.isBTC = false,
    this.isETH = false,
  });

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const Center(child: Text("等待數據累積...", style: TextStyle(color: Colors.white24, fontSize: 10)));

    final bool isBearish = history.last.sentiment.contains("跌");
    final List<double> netSeries;
    
    // Calculate Net Change Series relative to first point
    double getNet(HyperData d) {
      if (isPrinter) return isBearish ? (d.shortVolNum - d.longVolNum) : (d.longVolNum - d.shortVolNum);
      final coin = isBTC ? d.btc : d.eth;
      if (coin == null) return 0.0;
      return isBearish ? (coin.shortVol - coin.longVol) : (coin.longVol - coin.shortVol);
    }

    final double baseNet = getNet(history.first);
    netSeries = history.map((e) => getNet(e) - baseNet).toList();

    double minV = netSeries.reduce((c, n) => c < n ? c : n);
    double maxV = netSeries.reduce((c, n) => c > n ? c : n);
    
    // Buffer for better visualization
    if (minV == maxV) { minV -= 1000000; maxV += 1000000; }
    double range = maxV - minV;
    double pad = range * 0.15;

    final Color themeColor = isBearish ? const Color(0xFFFF4949) : const Color(0xFF00C087);

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
                        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)), // Increased from 9
                        Text(
                          "淨壓變動", 
                          style: TextStyle(color: themeColor.withAlpha(150), fontSize: 9, fontWeight: FontWeight.bold) // Increased from 8
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
                                return Text(DateFormat('HH:mm').format(history[idx].timestamp), style: const TextStyle(color: Colors.white24, fontSize: 8)); // Increased from 7
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
                                return Text(t, style: TextStyle(color: v >= 0 ? const Color(0xFF00C087).withAlpha(100) : const Color(0xFFFF4949).withAlpha(100), fontSize: 8), textAlign: TextAlign.right); // Increased from 7
                              },
                            ),
                          ),
                        ),
        
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (s) => const Color(0xFF2E2F33),
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        final idx = spot.x.toInt();
                        if (idx < 0 || idx >= history.length) return null;
                        final d = history[idx];
                        final val = netSeries[idx];
                        String fmt(double v) => (v >= 0 ? "+" : "") + (v.abs() >= 1e8 ? "${(v / 1e8).toStringAsFixed(2)}億" : "${(v / 1e4).toStringAsFixed(0)}萬");
                        return LineTooltipItem(
                          "${DateFormat('HH:mm:ss').format(d.timestamp)}\n${isBearish ? "淨空壓" : "淨多壓"}: ${fmt(val)}",
                          TextStyle(color: val >= 0 ? const Color(0xFF00C087) : const Color(0xFFFF4949), fontSize: 10, fontWeight: FontWeight.bold)
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
