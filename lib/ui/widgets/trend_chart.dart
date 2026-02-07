import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data_model.dart';

class TrendChart extends StatelessWidget {
  final String title;
  final List<HyperData> fullHistory;
  final List<HyperData> displayHistory;
  final bool isPrinter;
  final bool isBTC;
  final bool isETH;
  final bool isCombined;

  const TrendChart({
    super.key,
    required this.title,
    required this.fullHistory,
    required this.displayHistory,
    this.isPrinter = false,
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

    double getNet(HyperData d) {
      double l = 0.0;
      double s = 0.0;
      if (isPrinter) {
        l = d.longVolNum;
        s = d.shortVolNum;
      } else if (isCombined) {
        l = (d.btc?.longVol ?? 0) + (d.eth?.longVol ?? 0);
        s = (d.btc?.shortVol ?? 0) + (d.eth?.shortVol ?? 0);
      } else {
        final coin = isBTC ? d.btc : d.eth;
        l = coin?.longVol ?? 0;
        s = coin?.shortVol ?? 0;
      }
      return isBearish ? (s - l) : (l - s);
    }

    final double baseNet = getNet(displayHistory.first);
    final List<double> netSeries = displayHistory.map((e) => getNet(e) - baseNet).toList();

    double minV = netSeries.reduce((c, n) => c < n ? c : n);
    double maxV = netSeries.reduce((c, n) => c > n ? c : n);

    // 優化縮放：如果變動極小，給予最小 10 萬的範圍，否則按比例給予 15% 緩衝
    double range = (maxV - minV).abs();
    if (range < 100000) {
      double center = (maxV + minV) / 2;
      minV = center - 50000;
      maxV = center + 50000;
      range = 100000;
    }
    
    double pad = range * 0.15;

    final Color themeColor = isBearish ? const Color(0xFFFF2E2E) : const Color(0xFF00FF9D);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF050505), 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)), // 調亮
                Text(
                  netSeries.last >= 0 ? "勢能增強" : "勢能減弱",
                  style: TextStyle(color: themeColor, fontSize: 9, fontWeight: FontWeight.w900) // 強化顯示
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF1A1A1A).withAlpha(230),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final double val = spot.y;
                        String sign = val >= 0 ? "+" : "-";
                        double absV = val.abs();
                        String formatted = absV >= 1e8 
                          ? "$sign${(absV / 1e8).toStringAsFixed(2)}億" 
                          : absV >= 1e4 
                            ? "$sign${(absV / 1e4).toStringAsFixed(0)}萬" 
                            : "$sign${absV.toStringAsFixed(0)}";
                        
                        final time = DateFormat('HH:mm:ss').format(displayHistory[spot.x.toInt()].timestamp);
                        
                        return LineTooltipItem(
                          "$time\n",
                          const TextStyle(color: Colors.white38, fontSize: 10),
                          children: [
                            TextSpan(
                              text: formatted,
                              style: TextStyle(
                                color: val >= 0 ? const Color(0xFF00FF9D) : const Color(0xFFFF2E2E),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: false,
                  horizontalInterval: range > 0 ? range / 4 : 1000000,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withAlpha(10), strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 14,
                      getTitlesWidget: (v, m) {
                        int idx = v.toInt();
                        if (idx < 0 || idx >= displayHistory.length || idx % 180 != 0) return const SizedBox.shrink();
                        return Text(DateFormat('HH:mm').format(displayHistory[idx].timestamp), style: const TextStyle(color: Colors.white38, fontSize: 7)); // 調亮
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (v, m) {
                        if (v == minV - pad || v == maxV + pad) return const SizedBox.shrink();
                        String sign = v >= 0 ? "+" : "-";
                        double absV = v.abs();
                        String t = absV >= 1e8 ? "$sign${(v / 1e8).toStringAsFixed(1)}B" : absV >= 1e4 ? "$sign${(v / 1e4).toStringAsFixed(0)}W" : v.toStringAsFixed(0);
                        return Text(t, style: const TextStyle(color: Colors.white54, fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.right); // 調亮至 white54
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minV - pad, 
                maxY: maxV + pad,
                lineBarsData: [
                  LineChartBarData(
                    spots: netSeries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true, 
                    curveSmoothness: 0.1,
                    color: themeColor,
                    barWidth: 2.5, // 稍微加粗
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter,
                        colors: [themeColor.withAlpha(50), themeColor.withAlpha(0)],
                      ),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: 0, color: Colors.white.withAlpha(40), strokeWidth: 1, dashArray: [5, 5]), // 調亮零軸
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
