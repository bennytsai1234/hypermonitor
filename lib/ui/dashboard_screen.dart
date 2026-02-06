import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  HyperData? _currentData;
  DateTime? _lastDataChange; // Timestamp of the last actual value change
  bool _scraperReady = false;

  final List<HyperData> _history = [];
  final int _maxHistoryPoints = 360; // 60 minutes internal storage

  // Rainbow animation
  late AnimationController _rainbowController;
  bool _showRainbow = false;
  Timer? _rainbowTimer;

  // Sticky Deltas
  String? _lastBtcLongDelta;
  String? _lastBtcShortDelta;
  String? _lastBtcNetDelta;
  String? _lastEthLongDelta;
  String? _lastEthShortDelta;
  String? _lastEthNetDelta;
  String? _lastCombinedNetDelta;

  @override
  void initState() {
    super.initState();
    _rainbowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _scraperReady = true);
    });
  }

  @override
  void dispose() {
    _rainbowController.dispose();
    _rainbowTimer?.cancel();
    super.dispose();
  }

  void _triggerRainbow() {
    _rainbowTimer?.cancel();
    setState(() => _showRainbow = true);
    _rainbowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showRainbow = false);
    });
  }

  void _handleNewData(HyperData newData) {
    bool hasChanged = false;
    if (_currentData != null) {
      final old = _currentData!;
      final bool isBearish = newData.sentiment.contains("跌");
      
      // BTC Deltas: Update ONLY if the raw value has changed from the previous scrape
      if ((old.btc?.longVol ?? 0) != (newData.btc?.longVol ?? 0)) {
        _lastBtcLongDelta = _calculateVolumeDelta(old.btc?.longVol, newData.btc?.longVol ?? 0);
        hasChanged = true;
      }
      if ((old.btc?.shortVol ?? 0) != (newData.btc?.shortVol ?? 0)) {
        _lastBtcShortDelta = _calculateVolumeDelta(old.btc?.shortVol, newData.btc?.shortVol ?? 0);
        hasChanged = true;
      }
      
      final double oldBNet = isBearish ? ((old.btc?.shortVol ?? 0) - (old.btc?.longVol ?? 0)) : ((old.btc?.longVol ?? 0) - (old.btc?.shortVol ?? 0));
      final double newBNet = isBearish ? ((newData.btc?.shortVol ?? 0) - (newData.btc?.longVol ?? 0)) : ((newData.btc?.longVol ?? 0) - (newData.btc?.shortVol ?? 0));
      if (oldBNet != newBNet) {
        _lastBtcNetDelta = _calculateVolumeDelta(oldBNet, newBNet, isShortDelta: isBearish);
        hasChanged = true;
      }

      // ETH Deltas
      if ((old.eth?.longVol ?? 0) != (newData.eth?.longVol ?? 0)) {
        _lastEthLongDelta = _calculateVolumeDelta(old.eth?.longVol, newData.eth?.longVol ?? 0);
        hasChanged = true;
      }
      if ((old.eth?.shortVol ?? 0) != (newData.eth?.shortVol ?? 0)) {
        _lastEthShortDelta = _calculateVolumeDelta(old.eth?.shortVol, newData.eth?.shortVol ?? 0);
        hasChanged = true;
      }
      final double oldENet = isBearish ? ((old.eth?.shortVol ?? 0) - (old.eth?.longVol ?? 0)) : ((old.eth?.longVol ?? 0) - (old.eth?.shortVol ?? 0));
      final double newENet = isBearish ? ((newData.eth?.shortVol ?? 0) - (newData.eth?.longVol ?? 0)) : ((newData.eth?.longVol ?? 0) - (newData.eth?.shortVol ?? 0));
      if (oldENet != newENet) {
        _lastEthNetDelta = _calculateVolumeDelta(oldENet, newENet, isShortDelta: isBearish);
        hasChanged = true;
      }

      // Combined (Hedge) Delta
      final double oldCombined = oldBNet + oldENet;
      final double newCombined = newBNet + newENet;
      if (oldCombined != newCombined) {
        _lastCombinedNetDelta = _calculateVolumeDelta(oldCombined, newCombined, isShortDelta: isBearish);
        hasChanged = true;
      }
    } else {
      hasChanged = true;
    }

    setState(() {
      _currentData = newData;
      if (hasChanged) {
        _lastDataChange = DateTime.now();
        _triggerRainbow();
      }
      _history.add(newData);
      if (_history.length > _maxHistoryPoints) _history.removeAt(0);
    });
  }

  List<HyperData> _getHourHistory() {
    return _history;
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF000000); // OLED Black
    const cardBg = Color(0xFF050505); // Ultra dark for OLED
    const textGreen = Color(0xFF00C087);
    const textRed = Color(0xFFFF4949);
    const textGrey = Colors.white54;

    if (_currentData == null) {
      return Scaffold(
        backgroundColor: bgDark,
        body: Stack(
          children: [
            if (_scraperReady)
              Positioned(bottom: 0, right: 0, width: 1, height: 1,
                child: RepaintBoundary(child: Opacity(opacity: 0.0, child: CoinglassScraper(onDataScraped: _handleNewData)))),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: textGreen),
                  SizedBox(height: 20),
                  Text("正在同步 Coinglass 實時數據...", style: TextStyle(color: textGrey, fontSize: 12)),
                  Text("正在初始化穩定爬蟲 (約需 10-15 秒)", style: TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final btcLong = _currentData!.btc?.longVol ?? 0;
    final btcShort = _currentData!.btc?.shortVol ?? 0;
    final ethLong = _currentData!.eth?.longVol ?? 0;
    final ethShort = _currentData!.eth?.shortVol ?? 0;
    
    final bool isBearish = _currentData!.sentiment.contains("跌");
    final Color sentimentColor = isBearish ? textRed : textGreen;

    final combLong = btcLong + ethLong;
    final combShort = btcShort + ethShort;
    // Hedge net depends on sentiment mode
    final combNet = isBearish ? (combShort - combLong) : (combLong - combShort);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          if (_scraperReady)
            Positioned(bottom: 0, right: 0, width: 1, height: 1,
              child: RepaintBoundary(child: Opacity(opacity: 0.0, child: CoinglassScraper(onDataScraped: _handleNewData)))),

          // Rainbow border effect
          if (_showRainbow)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _rainbowController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 4,
                        color: HSVColor.fromAHSV(0.6, (_rainbowController.value * 360), 0.8, 1.0).toColor(),
                      ),
                    ),
                  );
                },
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text("超級印鈔機", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Text("| 對沖監控", style: TextStyle(color: textGrey, fontSize: 12)),
                      const Spacer(),
                      if (_lastDataChange != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(4)),
                          child: Text("變動時間: ${DateFormat('HH:mm:ss').format(_lastDataChange!)}", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(width: 12),
                      SentimentBadge(sentiment: _currentData!.sentiment),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAssetColumn("BTC", btcLong, btcShort, _currentData!.btc?.longDisplay ?? "---", _currentData!.btc?.shortDisplay ?? "---", _lastBtcLongDelta, _lastBtcShortDelta, _lastBtcNetDelta, isBearish, cardBg),
                      const SizedBox(width: 8),
                      _buildAssetColumn("ETH", ethLong, ethShort, _currentData!.eth?.longDisplay ?? "---", _currentData!.eth?.shortDisplay ?? "---", _lastEthLongDelta, _lastEthShortDelta, _lastEthNetDelta, isBearish, cardBg),
                      const SizedBox(width: 8),
                      // Combined Hedge Column
                      Expanded(
                        child: Column(
                          children: [
                            MetricCard(
                              label: isBearish ? "BTC+ETH 總空" : "BTC+ETH 總多", 
                              value: _formatVolume(isBearish ? combShort : combLong), 
                              delta: null, 
                              isShortDelta: isBearish,
                              color: sentimentColor, 
                              cardBg: cardBg
                            ),
                            const SizedBox(height: 8),
                            MetricCard(
                              label: isBearish ? "對沖淨空壓" : "對沖淨多壓", 
                              value: _formatVolume(combNet), 
                              delta: _lastCombinedNetDelta, 
                              isShortDelta: isBearish,
                              color: sentimentColor, 
                              cardBg: cardBg, 
                              isSmall: true
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: TugOfWarBar(label: "BTC 多空", leftVal: btcLong, rightVal: btcShort, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: cardBg)),
                      const SizedBox(width: 8),
                      Expanded(child: TugOfWarBar(label: "ETH 多空", leftVal: ethLong, rightVal: ethShort, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: cardBg)),
                      const SizedBox(width: 8),
                      Expanded(child: TugOfWarBar(label: "對沖佔比", leftVal: combLong, rightVal: combShort, leftColor: textGreen, rightColor: textRed, leftLabel: "總多", rightLabel: "總空", cardBg: cardBg)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                        child: Text("動態點: ${_getHourHistory().length}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text("※ 對沖總淨壓 = (BTC多-空) + (ETH多-空)。正值為淨多頭暴露，負值為淨空頭。平衡時趨近 0。", style: TextStyle(color: Colors.white12, fontSize: 9)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: TrendChart(title: "BTC 趨勢", fullHistory: _history, displayHistory: _getHourHistory(), isBTC: true)),
                        const SizedBox(width: 8),
                        Expanded(child: TrendChart(title: "ETH 趨勢", fullHistory: _history, displayHistory: _getHourHistory(), isETH: true)),
                        const SizedBox(width: 8),
                        Expanded(child: TrendChart(title: "對沖趨勢", fullHistory: _history, displayHistory: _getHourHistory(), isCombined: true)),
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

  Widget _buildAssetColumn(String name, double long, double short, String longDisp, String shortDisp, String? lDelta, String? sDelta, String? nDelta, bool isBearish, Color bg) {
    final double net = isBearish ? (short - long) : (long - short);
    const textGreen = Color(0xFF00C087);
    const textRed = Color(0xFFFF4949);
    final accent = isBearish ? textRed : textGreen;

    return Expanded(
      child: Column(
        children: [
          MetricCard(
            label: isBearish ? "$name 空單" : "$name 多單", 
            value: isBearish ? shortDisp : longDisp, 
            delta: isBearish ? sDelta : lDelta, 
            isShortDelta: isBearish,
            color: accent, 
            cardBg: bg
          ),
          const SizedBox(height: 8),
          MetricCard(
            label: isBearish ? "$name 淨空壓" : "$name 淨多壓", 
            value: _formatVolume(net), 
            delta: nDelta, 
            isShortDelta: isBearish,
            color: accent, 
            cardBg: bg, 
            isSmall: true
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

  String? _calculateVolumeDelta(double? prev, double curr, {bool isShortDelta = false}) {
    if (prev == null) return null;
    final diff = curr - prev;
    if (diff == 0) return null;
    final double absDiff = diff.abs();
    String formatted = absDiff >= 1e8 ? "${(absDiff / 1e8).toStringAsFixed(2)}億" : absDiff >= 1e4 ? "${(absDiff / 1e4).toStringAsFixed(0)}萬" : absDiff.toStringAsFixed(0);
    return "${diff > 0 ? "+" : "-"}\$$formatted";
  }
}
