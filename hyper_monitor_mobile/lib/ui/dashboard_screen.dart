import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';
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
  DateTime? _lastDataChange;
  bool _scraperReady = false;

  final List<HyperData> _history = [];
  final int _maxHistoryPoints = 8640; // 24 hours (10s interval)

  late AnimationController _rainbowController;
  bool _showRainbow = false;
  Timer? _rainbowTimer;

  // Sticky Deltas
  String? _lastBtcNetDelta;
  String? _lastEthNetDelta;
  String? _lastCombinedNetDelta;

  @override
  void initState() {
    super.initState();
    _rainbowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _scraperReady = true);
    });
  }

  @override
  void dispose() {
    _rainbowController.dispose();
    _rainbowTimer?.cancel();
    super.dispose();
  }

  void _triggerFeedback() async {
    _rainbowTimer?.cancel();
    setState(() => _showRainbow = true);
    
    // Haptic feedback for mobile
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100, amplitude: 128);
    }

    _rainbowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showRainbow = false);
    });
  }

  void _handleNewData(HyperData newData) {
    bool hasChanged = false;
    if (_currentData != null) {
      final old = _currentData!;
      final bool isBearish = newData.sentiment.contains("跌");
      
      final double oldBNet = (old.btc?.longVol ?? 0) - (old.btc?.shortVol ?? 0);
      final double newBNet = (newData.btc?.longVol ?? 0) - (newData.btc?.shortVol ?? 0);
      if (oldBNet != newBNet) {
        _lastBtcNetDelta = _calculateVolumeDelta(oldBNet, newBNet, isShortDelta: isBearish);
        hasChanged = true;
      }

      final double oldENet = (old.eth?.longVol ?? 0) - (old.eth?.shortVol ?? 0);
      final double newENet = (newData.eth?.longVol ?? 0) - (newData.eth?.shortVol ?? 0);
      if (oldENet != newENet) {
        _lastEthNetDelta = _calculateVolumeDelta(oldENet, newENet, isShortDelta: isBearish);
        hasChanged = true;
      }

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
        _triggerFeedback();
      }
      _history.add(newData);
      if (_history.length > _maxHistoryPoints) _history.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF000000);
    const cardBg = Color(0xFF0A0A0A);
    const textGreen = Color(0xFF00C087);
    const textRed = Color(0xFFFF4949);

    if (_currentData == null) {
      return Scaffold(
        backgroundColor: bgDark,
        body: Stack(
          children: [
            if (_scraperReady)
              Positioned(bottom: 0, right: 0, width: 1, height: 1,
                child: CoinglassScraper(onDataScraped: _handleNewData)),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: textGreen, strokeWidth: 2),
                  SizedBox(height: 24),
                  Text("HYPERLIQUID MONITOR", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  SizedBox(height: 8),
                  Text("正在同步 Coinglass 實時數據...", style: TextStyle(color: Colors.white30, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bool isBearish = _currentData!.sentiment.contains("跌");
    final Color sentimentColor = isBearish ? textRed : textGreen;
    final btcNet = (isBearish ? -1 : 1) * ((_currentData!.btc?.longVol ?? 0) - (_currentData!.btc?.shortVol ?? 0));
    final ethNet = (isBearish ? -1 : 1) * ((_currentData!.eth?.longVol ?? 0) - (_currentData!.eth?.shortVol ?? 0));
    final combinedNet = btcNet + ethNet;

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          if (_scraperReady)
            Positioned(bottom: 0, right: 0, width: 1, height: 1,
              child: CoinglassScraper(onDataScraped: _handleNewData)),

          if (_showRainbow)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _rainbowController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 3,
                        color: HSVColor.fromAHSV(0.5, (_rainbowController.value * 360), 0.8, 1.0).toColor(),
                      ),
                    ),
                  );
                },
              ),
            ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("超級印鈔機", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.black)),
                        Text("HYPERLIQUID MONITOR", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1)),
                      ],
                    ),
                    SentimentBadge(sentiment: _currentData!.sentiment),
                  ],
                ),
                if (_lastDataChange != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text("最後變動: ${DateFormat('HH:mm:ss').format(_lastDataChange!)}", 
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 24),

                // Asset Row BTC
                _buildSectionHeader("BTC / BITCOIN"),
                Row(
                  children: [
                    Expanded(child: MetricCard(label: isBearish ? "BTC 空單" : "BTC 多單", value: isBearish ? (_currentData!.btc?.shortDisplay ?? "---") : (_currentData!.btc?.longDisplay ?? "---"), delta: null, color: sentimentColor, cardBg: cardBg)),
                    const SizedBox(width: 12),
                    Expanded(child: MetricCard(label: isBearish ? "BTC 淨空壓" : "BTC 淨多壓", value: _formatVolume(btcNet), delta: _lastBtcNetDelta, color: sentimentColor, cardBg: cardBg, isSmall: true)),
                  ],
                ),
                const SizedBox(height: 12),
                TugOfWarBar(label: "BTC 多空拉鋸", leftVal: _currentData!.btc?.longVol ?? 0, rightVal: _currentData!.btc?.shortVol ?? 0, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: cardBg),
                
                const SizedBox(height: 24),

                // Asset Row ETH
                _buildSectionHeader("ETH / ETHEREUM"),
                Row(
                  children: [
                    Expanded(child: MetricCard(label: isBearish ? "ETH 空單" : "ETH 多單", value: isBearish ? (_currentData!.eth?.shortDisplay ?? "---") : (_currentData!.eth?.longDisplay ?? "---"), delta: null, color: sentimentColor, cardBg: cardBg)),
                    const SizedBox(width: 12),
                    Expanded(child: MetricCard(label: isBearish ? "ETH 淨空壓" : "ETH 淨多壓", value: _formatVolume(ethNet), delta: _lastEthNetDelta, color: sentimentColor, cardBg: cardBg, isSmall: true)),
                  ],
                ),
                const SizedBox(height: 12),
                TugOfWarBar(label: "ETH 多空拉鋸", leftVal: _currentData!.eth?.longVol ?? 0, rightVal: _currentData!.eth?.shortVol ?? 0, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: cardBg),

                const SizedBox(height: 24),

                // Hedge Section
                _buildSectionHeader("HEDGE / 對沖總覽"),
                MetricCard(label: isBearish ? "總淨空壓" : "總淨多壓", value: _formatVolume(combinedNet), delta: _lastCombinedNetDelta, color: sentimentColor, cardBg: cardBg),
                
                const SizedBox(height: 24),

                // Trend Section
                _buildSectionHeader("24H TREND / 趨勢圖"),
                SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(child: TrendChart(title: "BTC 淨壓", fullHistory: _history, displayHistory: _history, isBTC: true)),
                      const SizedBox(width: 8),
                      Expanded(child: TrendChart(title: "ETH 淨壓", fullHistory: _history, displayHistory: _history, isETH: true)),
                      const SizedBox(width: 8),
                      Expanded(child: TrendChart(title: "對沖趨勢", fullHistory: _history, displayHistory: _history, isCombined: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: Text("採集點: ${_history.length} / 8640", style: const TextStyle(color: Colors.white10, fontSize: 9))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(title, style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
    double diff = curr - prev;
    if (isShortDelta) diff = -diff;
    if (diff == 0) return null;
    final double absDiff = diff.abs();
    String formatted = absDiff >= 1e8 ? "${(absDiff / 1e8).toStringAsFixed(2)}億" : absDiff >= 1e4 ? "${(absDiff / 1e4).toStringAsFixed(0)}萬" : absDiff.toStringAsFixed(0);
    return "${diff > 0 ? "+" : "-"}\$$formatted";
  }
}
