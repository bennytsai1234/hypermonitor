import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
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

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin, WindowListener {
  HyperData? _currentData;
  DateTime? _lastDataChange;
  bool _scraperReady = false;

  final List<HyperData> _history = [];
  final int _maxHistoryPoints = 8640; 

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
  String? _lastCombinedLongDelta;
  String? _lastCombinedShortDelta;
  String? _lastCombinedNetDelta;
  String? _lastPrinterLongDelta;
  String? _lastPrinterShortDelta;
  String? _lastPrinterNetDelta;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _rainbowController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _scraperReady = true);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _rainbowController.dispose();
    _rainbowTimer?.cancel();
    super.dispose();
  }

  void _toggleFullscreen() async {
    bool isFullScreen = await windowManager.isFullScreen();
    if (isFullScreen) {
      await windowManager.setFullScreen(false);
      await windowManager.setHasShadow(true);
    } else {
      if (await windowManager.isMaximized()) await windowManager.unmaximize();
      await windowManager.setFullScreen(true);
    }
  }

  void _triggerRainbow() {
    _rainbowTimer?.cancel();
    setState(() => _showRainbow = true);
    _rainbowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showRainbow = false);
    });
  }

  // --- 獨立更新邏輯：全體數據 ---
  void _onPrinterScraped(HyperData newData) {
    if (_currentData == null) {
      setState(() => _currentData = newData);
      return;
    }

    final old = _currentData!;
    bool changed = false;
    final bool isBearish = newData.sentiment.contains("跌");

    // 只有當數值變動超過 5萬 美金才視為更新
    String? check(double o, double n) => (n - o).abs() > 50000 ? _calculateRawDelta(o, n) : null;

    final lDelta = check(old.longVolNum, newData.longVolNum);
    final sDelta = check(old.shortVolNum, newData.shortVolNum);
    
    final double oldPN = isBearish ? (old.shortVolNum - old.longVolNum) : (old.longVolNum - old.shortVolNum);
    final double newPN = isBearish ? (newData.shortVolNum - newData.longVolNum) : (newData.longVolNum - newData.shortVolNum);
    final nDelta = check(oldPN, newPN);

    if (lDelta != null || sDelta != null || nDelta != null) {
      changed = true;
      _lastPrinterLongDelta = lDelta;
      _lastPrinterShortDelta = sDelta;
      _lastPrinterNetDelta = nDelta;
    }

    setState(() {
      // 更新全體相關欄位，保留舊的資產數據
      _currentData = newData; 
      if (changed) {
        _lastDataChange = DateTime.now();
        _triggerRainbow();
      }
    });
  }

  // --- 獨立更新邏輯：BTC/ETH 數據 ---
  void _onRangeScraped(HyperData newData) {
    if (_currentData == null) {
      setState(() => _currentData = newData);
      return;
    }

    final old = _currentData!;
    bool changed = false;
    final bool isBearish = newData.sentiment.contains("跌");

    String? check(double o, double n) => (n - o).abs() > 50000 ? _calculateRawDelta(o, n) : null;

    // BTC
    final blDelta = check(old.btc?.longVol ?? 0, newData.btc?.longVol ?? 0);
    final bsDelta = check(old.btc?.shortVol ?? 0, newData.btc?.shortVol ?? 0);
    final double oldBNet = isBearish ? ((old.btc?.shortVol ?? 0) - (old.btc?.longVol ?? 0)) : ((old.btc?.longVol ?? 0) - (old.btc?.shortVol ?? 0));
    final double newBNet = isBearish ? ((newData.btc?.shortVol ?? 0) - (newData.btc?.longVol ?? 0)) : ((newData.btc?.longVol ?? 0) - (newData.btc?.shortVol ?? 0));
    final bnDelta = check(oldBNet, newBNet);

    // ETH
    final elDelta = check(old.eth?.longVol ?? 0, newData.eth?.longVol ?? 0);
    final esDelta = check(old.eth?.shortVol ?? 0, newData.eth?.shortVol ?? 0);
    final double oldENet = isBearish ? ((old.eth?.shortVol ?? 0) - (old.eth?.longVol ?? 0)) : ((old.eth?.longVol ?? 0) - (old.eth?.shortVol ?? 0));
    final double newENet = isBearish ? ((newData.eth?.shortVol ?? 0) - (newData.eth?.longVol ?? 0)) : ((newData.eth?.longVol ?? 0) - (newData.eth?.shortVol ?? 0));
    final enDelta = check(oldENet, newENet);

    // Combined
    final double oldCL = (old.btc?.longVol ?? 0) + (old.eth?.longVol ?? 0);
    final double newCL = (newData.btc?.longVol ?? 0) + (newData.eth?.longVol ?? 0);
    final clDelta = check(oldCL, newCL);
    final double oldCS = (old.btc?.shortVol ?? 0) + (old.eth?.shortVol ?? 0);
    final double newCS = (newData.btc?.shortVol ?? 0) + (newData.eth?.shortVol ?? 0);
    final csDelta = check(oldCS, newCS);
    final double oldCN = isBearish ? (oldCS - oldCL) : (oldCL - oldCS);
    final double newCN = isBearish ? (newCS - newCL) : (newCL - newCS);
    final cnDelta = check(oldCN, newCN);

    if (blDelta != null || bsDelta != null || bnDelta != null || elDelta != null || esDelta != null || enDelta != null || clDelta != null || csDelta != null || cnDelta != null) {
      changed = true;
      _lastBtcLongDelta = blDelta; _lastBtcShortDelta = bsDelta; _lastBtcNetDelta = bnDelta;
      _lastEthLongDelta = elDelta; _lastEthShortDelta = esDelta; _lastEthNetDelta = enDelta;
      _lastCombinedLongDelta = clDelta; _lastCombinedShortDelta = csDelta; _lastCombinedNetDelta = cnDelta;
    }

    setState(() {
      _currentData = newData;
      if (changed) {
        _lastDataChange = DateTime.now();
        _triggerRainbow();
      }
      _history.add(newData);
      if (_history.length > _maxHistoryPoints) _history.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF000000); 
    const cardBg = Color(0xFF080808); 
    const textGreen = Color(0xFF00FF9D); 
    const textRed = Color(0xFFFF2E2E); 

    if (_currentData == null) {
      return Scaffold(
        backgroundColor: bgDark,
        body: Stack(
          children: [
            if (_scraperReady)
              Positioned(bottom: 0, right: 0, width: 1, height: 1,
                child: Opacity(opacity: 0.0, child: CoinglassScraper(
                  onPrinterData: _onPrinterScraped,
                  onRangeData: _onRangeScraped,
                ))),
            const Center(child: CircularProgressIndicator(color: textGreen, strokeWidth: 3)),
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
    final combNet = isBearish ? (combShort - combLong) : (combLong - combShort);
    final printerNet = isBearish ? (_currentData!.shortVolNum - _currentData!.longVolNum) : (_currentData!.longVolNum - _currentData!.shortVolNum);

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: bgDark,
        body: Stack(
          children: [
            if (_scraperReady)
              Positioned(bottom: 0, right: 0, width: 1, height: 1,
                child: Opacity(opacity: 0.0, child: CoinglassScraper(
                  onPrinterData: _onPrinterScraped,
                  onRangeData: _onRangeScraped,
                ))),

            if (_showRainbow)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rainbowController,
                  builder: (context, child) {
                    final color = HSVColor.fromAHSV(0.4, (_rainbowController.value * 360), 0.8, 1.0).toColor();
                    return Container(
                      decoration: BoxDecoration(border: Border.all(color: color, width: 20), color: color.withAlpha(80)),
                    );
                  },
                ),
              ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildHeader(cardBg),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          // 左：全體
                          Expanded(child: _buildColumn(
                            title: "全體印鈔機", icon: Icons.public, accent: Colors.white, bg: cardBg,
                            children: [
                              MetricCard(label: isBearish ? "全體淨空壓" : "全體淨多壓", value: _formatVolume(printerNet), delta: _lastPrinterNetDelta, color: sentimentColor, cardBg: Colors.white.withAlpha(5), highlightValue: true, useColorBorder: true),
                              const SizedBox(height: 8),
                              MetricCard(label: "全體總多單", value: _currentData!.longVolDisplay, delta: _lastPrinterLongDelta, color: textGreen, cardBg: Colors.white.withAlpha(2), isSmall: true),
                              const SizedBox(height: 6),
                              MetricCard(label: "全體總空單", value: _currentData!.shortVolDisplay, delta: _lastPrinterShortDelta, color: textRed, cardBg: Colors.white.withAlpha(2), isSmall: true),
                              const SizedBox(height: 10),
                              TugOfWarBar(label: "全體比例", leftVal: _currentData!.longVolNum, rightVal: _currentData!.shortVolNum, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
                              const SizedBox(height: 10),
                              Expanded(child: TrendChart(title: "全體淨值流向 (24H)", fullHistory: _history, displayHistory: _history, isPrinter: true)),
                            ],
                          )),
                          const SizedBox(width: 10),
                          // 中：對沖
                          Expanded(child: _buildColumn(
                            title: "核心對沖", icon: Icons.layers, accent: Colors.blueAccent, bg: cardBg,
                            children: [
                              MetricCard(label: isBearish ? "對沖淨空壓" : "對沖淨多壓", value: _formatVolume(combNet), delta: _lastCombinedNetDelta, color: sentimentColor, cardBg: Colors.white.withAlpha(5), highlightValue: true, useColorBorder: true),
                              const SizedBox(height: 8),
                              MetricCard(label: "核心總多單", value: _formatVolume(combLong), delta: _lastCombinedLongDelta, color: textGreen, cardBg: Colors.white.withAlpha(2), isSmall: true),
                              const SizedBox(height: 6),
                              MetricCard(label: "核心總空單", value: _formatVolume(combShort), delta: _lastCombinedShortDelta, color: textRed, cardBg: Colors.white.withAlpha(2), isSmall: true),
                              const SizedBox(height: 10),
                              TugOfWarBar(label: "對沖比例", leftVal: combLong, rightVal: combShort, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
                              const SizedBox(height: 10),
                              Expanded(child: TrendChart(title: "對沖淨值流向 (24H)", fullHistory: _history, displayHistory: _history, isCombined: true)),
                            ],
                          )),
                          const SizedBox(width: 10),
                          // 右：BTC & ETH
                          Expanded(flex: 2, child: Row(
                            children: [
                              Expanded(child: _buildAssetSub("BTC", const Color(0xFFF7931A), btcLong, btcShort, _currentData!.btc?.longDisplay ?? "-", _currentData!.btc?.shortDisplay ?? "-", _lastBtcLongDelta, _lastBtcShortDelta, _lastBtcNetDelta, isBearish, cardBg, textGreen, textRed)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildAssetSub("ETH", const Color(0xFF627EEA), ethLong, ethShort, _currentData!.eth?.longDisplay ?? "-", _currentData!.eth?.shortDisplay ?? "-", _lastEthLongDelta, _lastEthShortDelta, _lastEthNetDelta, isBearish, cardBg, textGreen, textRed)),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          const Icon(Icons.electric_bolt_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          const Text("超級印鈔機", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(width: 12),
          SentimentBadge(sentiment: _currentData!.sentiment),
          const Spacer(),
          if (_lastDataChange != null)
            Text("最後更新: ${DateFormat('HH:mm:ss').format(_lastDataChange!)}", style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAssetSub(String name, Color accent, double long, double short, String lDisp, String sDisp, String? lDelta, String? sDelta, String? nDelta, bool isBearish, Color bg, Color green, Color red) {
    final double netRaw = isBearish ? (short - long) : (long - short);
    return _buildColumn(
      title: "$name 監控", icon: Icons.analytics, accent: accent, bg: bg,
      children: [
        MetricCard(label: isBearish ? "$name 淨空壓" : "$name 淨多壓", value: _formatVolume(netRaw), delta: nDelta, color: isBearish ? red : green, cardBg: Colors.white.withAlpha(5), useColorBorder: true),
        const SizedBox(height: 8),
        MetricCard(label: "多單持倉", value: lDisp, delta: lDelta, color: green, cardBg: Colors.white.withAlpha(2), isSmall: true),
        const SizedBox(height: 6),
        MetricCard(label: "空單持倉", value: sDisp, delta: sDelta, color: red, cardBg: Colors.white.withAlpha(2), isSmall: true),
        const SizedBox(height: 10),
        TugOfWarBar(label: "持倉比例", leftVal: long, rightVal: short, leftColor: green, rightColor: red, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
        const SizedBox(height: 10),
        Expanded(child: TrendChart(title: "$name 資金趨勢", fullHistory: _history, displayHistory: _history, isBTC: name == "BTC", isETH: name == "ETH")),
      ],
    );
  }

  Widget _buildColumn({required String title, required IconData icon, required Color accent, required Color bg, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: accent, size: 12),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 16, color: Colors.white10),
          ...children,
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

  String? _calculateRawDelta(double? prev, double curr) {
    if (prev == null) return null;
    double diff = curr - prev;
    if (diff == 0) return null;
    final double absDiff = diff.abs();
    String formatted = absDiff >= 1e8 ? "${(absDiff / 1e8).toStringAsFixed(2)}億" : absDiff >= 1e4 ? "${(absDiff / 1e4).toStringAsFixed(0)}萬" : absDiff.toStringAsFixed(0);
    return "${diff > 0 ? "+" : "-"}\$$formatted";
  }
}
