import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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
    if (displayHistory.isEmpty) return Container();

    final List<FlSpot> spots = [];
    for (int i = 0; i < displayHistory.length; i++) {
      double val = 0;
      final d = displayHistory[i];
      if (isBTC) {
        val = (d.btc?.longVol ?? 0) - (d.btc?.shortVol ?? 0);
      } else if (isETH) {
        val = (d.eth?.longVol ?? 0) - (d.eth?.shortVol ?? 0);
      } else if (isCombined) {
        final bNet = (d.btc?.longVol ?? 0) - (d.btc?.shortVol ?? 0);
        final eNet = (d.eth?.longVol ?? 0) - (d.eth?.shortVol ?? 0);
        val = bNet + eNet;
      }
      spots.add(FlSpot(i.toDouble(), val / 1000000.0)); // In Millions for scaling
    }

    final bool isBullish = spots.isNotEmpty && spots.last.y >= 0;
    final color = isBullish ? const Color(0xFF00C087) : const Color(0xFFFF4949);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withAlpha(20),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(y: 0, color: Colors.white10, strokeWidth: 1, dashArray: [5, 5]),
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
