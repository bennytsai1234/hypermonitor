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
          // Background Scraper
          Opacity(
              opacity: 0.0,
              child: CoinglassScraper(onDataScraped: _handleNewData),
          ),

          // Main Content
          Center(
            child: _currentData == null
              ? const CircularProgressIndicator(color: Color(0xFF00C087))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(textGreen),
                        const SizedBox(height: 30),

                        // Super Money Printer Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                               Text(
                                "SUPER MONEY PRINTER",
                                style: TextStyle(
                                  color: textGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "超级印钞机",
                                style: TextStyle(
                                  color: textWhite,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 30),

                              _buildRowItem("Wallets", "${_currentData!.walletCount}",
                                delta: _calculateIntDelta(_previousData?.walletCount, _currentData!.walletCount),
                                valueColor: textWhite,
                              ),
                              const Divider(height: 30, color: Colors.white10),

                              _buildRowItem("Long Vol (多)", _currentData!.longVolDisplay,
                                delta: _calculateVolumeDelta(_previousData?.longVolNum, _currentData!.longVolNum),
                                valueColor: textGreen,
                                subValue: "多单持仓",
                              ),
                              const Divider(height: 30, color: Colors.white10),

                              _buildRowItem("Short Vol (空)", _currentData!.shortVolDisplay,
                                delta: _calculateVolumeDelta(_previousData?.shortVolNum, _currentData!.shortVolNum), // Red for increase in shorts
                                valueColor: textRed,
                                subValue: "空单持仓",
                              ),
                              const Divider(height: 30, color: Colors.white10),

                              _buildRowItem("Net Vol (净)", _currentData!.netVolDisplay,
                                delta: _calculateVolumeDelta(_previousData?.netVolNum, _currentData!.netVolNum),
                                valueColor: Colors.blueAccent,
                                subValue: "总仓位",
                              ),

                              const SizedBox(height: 20),
                              if (_lastUpdate != null)
                                Text(
                                  "Last updated: ${DateFormat('HH:mm:ss').format(_lastUpdate!)}",
                                  style: TextStyle(color: textGrey, fontSize: 12),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Charts Section
                        if (_history.length > 2) ...[
                          _buildChartCard("Long Trend (多)", _history.map((e) => e.longVolNum).toList(), textGreen),
                          const SizedBox(height: 15),
                          _buildChartCard("Short Trend (空)", _history.map((e) => e.shortVolNum).toList(), textRed),
                        ]
                      ],
                    ),
                  ),
                ),
          ),
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
          "Real-time Tracking",
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRowItem(String label, String value, {String? delta, Color? valueColor, String? subValue}) {
     return Row(
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
                 color: delta.startsWith('+') ? const Color(0xFF00C087) : const Color(0xFFFF4949),
                 fontSize: 14,
                 fontWeight: FontWeight.bold
               )),
           ],
         )
       ],
     );
  }

  Widget _buildChartCard(String title, List<double> dataPoints, Color lineColor) {
     if (dataPoints.isEmpty) return const SizedBox.shrink();

     double minVal = dataPoints.reduce((curr, next) => curr < next ? curr : next);
     double maxVal = dataPoints.reduce((curr, next) => curr > next ? curr : next);

     // Add output padding
     final double padding = (maxVal - minVal) * 0.1;
     if (padding == 0) { // Flat line
         minVal -= 1000;
         maxVal += 1000;
     } else {
         minVal -= padding;
         maxVal += padding;
     }

     return Container(
       height: 150,
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: const Color(0xFF16171B).withOpacity(0.8),
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
                 minY: minVal,
                 maxY: maxVal,
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

  String? _calculateVolumeDelta(double? prev, double curr) {
    if (prev == null) return null;
    final diff = curr - prev;
    if (diff == 0) return null;

    String formatted;
    double absDiff = diff.abs();

    if (absDiff >= 100000000) {
      formatted = "\$${(diff / 100000000).toStringAsFixed(2)}亿";
    } else if (absDiff >= 10000) {
      formatted = "\$${(diff / 10000).toStringAsFixed(2)}万";
    } else {
       formatted = "\$${diff.toStringAsFixed(0)}";
    }

    return diff > 0 ? "+$formatted" : formatted;
  }
}
