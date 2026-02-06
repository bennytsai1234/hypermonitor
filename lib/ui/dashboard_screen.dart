import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/data_model.dart';
import '../core/data_scraper.dart';
import 'widgets/sentiment_badge.dart';
import 'widgets/metric_card.dart';
import 'widgets/tug_of_war_bar.dart';
import 'widgets/trend_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  HyperData? _currentData;
  DateTime? _lastUpdate;
  bool _scraperReady = false;

  final List<HyperData> _history = [];
  final int _maxHistoryPoints = 360; // 60 minutes internal storage

  // Sticky Deltas: Store the last observed changes
  String? _lastPrinterLongDelta;
  String? _lastPrinterShortDelta;
  String? _lastPrinterNetDelta;
  
  String? _lastBtcLongDelta;
  String? _lastBtcShortDelta;
  String? _lastBtcNetDelta;
  
  String? _lastEthLongDelta;
  String? _lastEthShortDelta;
  String? _lastEthNetDelta;

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
      final old = _currentData!;
      final bool isBearish = newData.sentiment.contains("跌");

      // 1. Printer Deltas
      if (old.longVolNum != newData.longVolNum) {
        _lastPrinterLongDelta = _calculateVolumeDelta(old.longVolNum, newData.longVolNum);
      }
      if (old.shortVolNum != newData.shortVolNum) {
        _lastPrinterShortDelta = _calculateVolumeDelta(old.shortVolNum, newData.shortVolNum);
      }
      
      final double oldPNet = isBearish ? (old.shortVolNum - old.longVolNum) : (old.longVolNum - old.shortVolNum);
      final double newPNet = isBearish ? (newData.shortVolNum - newData.longVolNum) : (newData.longVolNum - newData.shortVolNum);
      if (oldPNet != newPNet) {
        _lastPrinterNetDelta = _calculateVolumeDelta(oldPNet, newPNet, isShortDelta: isBearish);
      }

      // 2. BTC Deltas
      if ((old.btc?.longVol ?? 0) != (newData.btc?.longVol ?? 0)) {
        _lastBtcLongDelta = _calculateVolumeDelta(old.btc?.longVol, newData.btc?.longVol ?? 0);
      }
      if ((old.btc?.shortVol ?? 0) != (newData.btc?.shortVol ?? 0)) {
        _lastBtcShortDelta = _calculateVolumeDelta(old.btc?.shortVol, newData.btc?.shortVol ?? 0);
      }
      
      final double oldBNet = isBearish ? ((old.btc?.shortVol ?? 0) - (old.btc?.longVol ?? 0)) : ((old.btc?.longVol ?? 0) - (old.btc?.shortVol ?? 0));
      final double newBNet = isBearish ? ((newData.btc?.shortVol ?? 0) - (newData.btc?.longVol ?? 0)) : ((newData.btc?.longVol ?? 0) - (newData.btc?.shortVol ?? 0));
      if (oldBNet != newBNet) {
        _lastBtcNetDelta = _calculateVolumeDelta(oldBNet, newBNet, isShortDelta: isBearish);
      }

      // 3. ETH Deltas
      if ((old.eth?.longVol ?? 0) != (newData.eth?.longVol ?? 0)) {
        _lastEthLongDelta = _calculateVolumeDelta(old.eth?.longVol, newData.eth?.longVol ?? 0);
      }
      if ((old.eth?.shortVol ?? 0) != (newData.eth?.shortVol ?? 0)) {
        _lastEthShortDelta = _calculateVolumeDelta(old.eth?.shortVol, newData.eth?.shortVol ?? 0);
      }
      
      final double oldENet = isBearish ? ((old.eth?.shortVol ?? 0) - (old.eth?.longVol ?? 0)) : ((old.eth?.longVol ?? 0) - (old.eth?.shortVol ?? 0));
      final double newENet = isBearish ? ((newData.eth?.shortVol ?? 0) - (newData.eth?.longVol ?? 0)) : ((newData.eth?.longVol ?? 0) - (newData.eth?.shortVol ?? 0));
      if (oldENet != newENet) {
        _lastEthNetDelta = _calculateVolumeDelta(oldENet, newENet, isShortDelta: isBearish);
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

  // Helper for 10 min charts
  List<HyperData> _get10MinHistory() {
    if (_history.length <= 60) return _history; // 60 * 10s = 10 mins
    return _history.sublist(_history.length - 60);
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0D0E12);
    const cardBg = Color(0xFF16171B);
    const textGreen = Color(0xFF00C087);
    const textRed = Color(0xFFFF4949);
    const textGrey = Colors.white54;

    if (_currentData == null) {
      return const Scaffold(
        backgroundColor: bgDark,
        body: Center(child: CircularProgressIndicator(color: textGreen)),
      );
    }

    final bool isBearish = _currentData!.sentiment.contains("跌");
    final Color sentimentColor = _getSentimentColor(_currentData!.sentiment);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          if (_scraperReady)
            Positioned(bottom: 0, right: 0, width: 1, height: 1,
              child: RepaintBoundary(child: Opacity(opacity: 0.0, child: CoinglassScraper(onDataScraped: _handleNewData)))),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // HEADER
                  Row(
                    children: [
                      const Text("超級印鈔機", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Text("| 實時監控", style: TextStyle(color: textGrey, fontSize: 12)),
                      const Spacer(),
                      if (_lastUpdate != null)
                        Text("${DateFormat('HH:mm:ss').format(_lastUpdate!)} ", style: const TextStyle(color: textGrey, fontSize: 10, fontFamily: 'monospace')),
                      SentimentBadge(sentiment: _currentData!.sentiment),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ROW 1: 3-COLUMN METRICS
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAssetColumn("總體", _currentData!.longVolNum, _currentData!.shortVolNum, _currentData!.longVolDisplay, _currentData!.shortVolDisplay, _lastPrinterLongDelta, _lastPrinterShortDelta, _lastPrinterNetDelta, isBearish, sentimentColor, cardBg),
                      const SizedBox(width: 8),
                      _buildAssetColumn("BTC", _currentData!.btc?.longVol ?? 0, _currentData!.btc?.shortVol ?? 0, _currentData!.btc?.longDisplay ?? "---", _currentData!.btc?.shortDisplay ?? "---", _lastBtcLongDelta, _lastBtcShortDelta, _lastBtcNetDelta, isBearish, isBearish ? textRed : textGreen, cardBg),
                      const SizedBox(width: 8),
                      _buildAssetColumn("ETH", _currentData!.eth?.longVol ?? 0, _currentData!.eth?.shortVol ?? 0, _currentData!.eth?.longDisplay ?? "---", _currentData!.eth?.shortDisplay ?? "---", _lastEthLongDelta, _lastEthShortDelta, _lastEthNetDelta, isBearish, isBearish ? textRed : textGreen, cardBg),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ROW 2: 3-COLUMN TUG OF WAR (L/S Ratios)
                  Row(
                    children: [
                      Expanded(child: TugOfWarBar(label: "總體多空比", leftVal: _currentData!.longVolNum, rightVal: _currentData!.shortVolNum, leftColor: textGreen, rightColor: textRed, leftLabel: "多頭", rightLabel: "空頭", cardBg: cardBg)),
                      const SizedBox(width: 8),
                      Expanded(child: TugOfWarBar(label: "BTC 多空比", leftVal: _currentData!.btc?.longVol ?? 0, rightVal: _currentData!.btc?.shortVol ?? 0, leftColor: textGreen, rightColor: textRed, leftLabel: "多頭", rightLabel: "空頭", cardBg: cardBg)),
                      const SizedBox(width: 8),
                      Expanded(child: TugOfWarBar(label: "ETH 多空比", leftVal: _currentData!.eth?.longVol ?? 0, rightVal: _currentData!.eth?.shortVol ?? 0, leftColor: textGreen, rightColor: textRed, leftLabel: "多頭", rightLabel: "空頭", cardBg: cardBg)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ROW 3: PROFIT/LOSS & STATUS
                  Row(
                    children: [
                      Expanded(child: TugOfWarBar(label: isBearish ? "空軍盈利中" : "多頭盈利中", leftVal: _currentData!.profitCount.toDouble(), rightVal: _currentData!.lossCount.toDouble(), leftColor: textGreen, rightColor: textRed, leftLabel: "賺錢", rightLabel: "虧錢", cardBg: cardBg)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                        child: Text("10m 動態點: ${_get10MinHistory().length}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ROW 4: CHARTS
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: TrendChart(title: "總體 10m 變動", history: _get10MinHistory(), isPrinter: true)),
                        const SizedBox(width: 8),
                        Expanded(child: TrendChart(title: "BTC 10m 變動", history: _get10MinHistory(), isBTC: true)),
                        const SizedBox(width: 8),
                        Expanded(child: TrendChart(title: "ETH 10m 變動", history: _get10MinHistory(), isETH: true)),
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

  Widget _buildAssetColumn(String name, double long, double short, String longDisp, String shortDisp, String? lDelta, String? sDelta, String? nDelta, bool isBearish, Color accent, Color bg) {
    final double net = isBearish ? (short - long) : (long - short);
    
    return Expanded(
      child: Column(
        children: [
          MetricCard(
            label: isBearish ? "$name 空單" : "$name 多單",
            value: isBearish ? shortDisp : longDisp,
            delta: isBearish ? sDelta : lDelta,
            isShortDelta: isBearish,
            color: accent,
            cardBg: bg,
          ),
          const SizedBox(height: 8),
          MetricCard(
            label: isBearish ? "$name 淨空壓" : "$name 淨多壓",
            value: _formatVolume(net),
            delta: nDelta,
            isShortDelta: isBearish,
            color: accent,
            cardBg: bg,
            isSmall: true,
          ),
        ],
      ),
    );
  }

  String _formatVolume(double v) {
    String sign = v >= 0 ? "+" : "";
    double absV = v.abs();
    if (absV >= 1e8) return "$sign\$${(v / 1e8).toStringAsFixed(2)}億";
    if (absV >= 1e4) return "$sign\$${(v / 1e4).toStringAsFixed(0)}萬";
    return "$sign\$${v.toStringAsFixed(0)}";
  }

  Color _getSentimentColor(String text) {
    if (text.contains("非常")) return text.contains("跌") ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
    if (text.contains("略")) return text.contains("跌") ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7);
    if (text.contains("跌")) return const Color(0xFFFF4949);
    return (text.contains("漲") || text.contains("涨")) ? const Color(0xFF00C087) : Colors.grey;
  }

  String? _calculateVolumeDelta(double? prev, double curr, {bool isShortDelta = false}) {
    if (prev == null) return null;
    final diff = curr - prev;
    if (diff == 0) return null;
    
    final double absDiff = diff.abs();
    String formatted;
    if (absDiff >= 1e8) {
      formatted = "${(absDiff / 1e8).toStringAsFixed(2)}億";
    } else if (absDiff >= 1e4) {
      formatted = "${(absDiff / 1e4).toStringAsFixed(0)}萬";
    } else {
      formatted = absDiff.toStringAsFixed(0);
    }
    
    final String sign = diff > 0 ? "+" : "-";
    return "$sign\$$formatted";
  }
}
