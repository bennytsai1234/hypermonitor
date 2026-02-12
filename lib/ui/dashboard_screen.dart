import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import '../core/data_model.dart';
import '../core/data_scraper.dart';
import '../core/api_service.dart';
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
  final ApiService _apiService = ApiService();
  HyperData? _currentData;
  DateTime? _lastDataChange;

  Map<String, List<HyperData>> _historyMap = {'printer': [], 'btc': [], 'eth': [], 'combined': []};
  String _selectedRange = "1h";
  bool _isLoadingHistory = false;

  Timer? _pollingTimer;
  Timer? _historyTimer;
  late AnimationController _rainbowController;
  bool _showRainbow = false;
  Timer? _rainbowTimer;
  late FocusNode _mainFocusNode;

  // History refresh interval (5 minutes, same as PWA)
  static const _historyRefreshInterval = Duration(minutes: 5);

  // Delta 緩衝區
  String? _lastBtcLongDelta; String? _lastBtcShortDelta; String? _lastBtcNetDelta;
  String? _lastEthLongDelta; String? _lastEthShortDelta; String? _lastEthNetDelta;
  String? _lastCombinedLongDelta; String? _lastCombinedShortDelta; String? _lastCombinedNetDelta;
  String? _lastPrinterLongDelta; String? _lastPrinterShortDelta; String? _lastPrinterNetDelta;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _mainFocusNode = FocusNode();
    _rainbowController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

    _pollLatest();
    _loadHistory();

    // Poll /latest every 10 seconds (lightweight)
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollLatest());
    // Poll /history every 5 minutes (heavy query, reduce DB reads)
    _historyTimer = Timer.periodic(_historyRefreshInterval, (_) => _loadHistory(silent: true));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _mainFocusNode.requestFocus();
    });
  }


  Future<void> _pollLatest() async {
    final newData = await _apiService.fetchLatest();
    if (newData == null) return;
    if (_currentData != null) _calculateDeltas(_currentData!, newData);
    if (mounted) {
      setState(() {
        _currentData = newData;
        _lastDataChange = DateTime.now().toTaiwanTime();
      });
    }
  }

  /// 比較兩個歷史列表是否相同（長度 + 最後一筆時間戳）
  bool _isHistorySame(List<HyperData> oldList, List<HyperData> newList) {
    if (oldList.length != newList.length) return false;
    if (oldList.isEmpty) return true;
    return oldList.last.timestamp == newList.last.timestamp;
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingHistory = true);
    final history = await _apiService.fetchHistory(_selectedRange);

    // --- 關鍵修正：對齊並合併 BTC 與 ETH 的歷史數據 ---
    List<HyperData> combinedHistory = [];
    final btcList = history['btc'] ?? [];
    final ethList = history['eth'] ?? [];

    // 取較短的那一邊進行對齊合併
    int count = btcList.length < ethList.length ? btcList.length : ethList.length;
    for (int i = 0; i < count; i++) {
      combinedHistory.add(HyperData(
        timestamp: btcList[i].timestamp,
        walletCount: 0, profitCount: 0, lossCount: 0,
        longVolDisplay: "", shortVolDisplay: "", netVolDisplay: "",
        sentiment: _currentData?.sentiment ?? "中性",
        longVolNum: 0, shortVolNum: 0, netVolNum: 0,
        btc: btcList[i].btc,
        eth: ethList[i].eth,
      ));
    }

    if (mounted) {
      // 靜默模式下，比較新舊數據，沒有變化就跳過重繪
      if (silent) {
        final oldPrinter = _historyMap['printer'] ?? [];
        final oldBtc = _historyMap['btc'] ?? [];
        final oldEth = _historyMap['eth'] ?? [];
        final newPrinter = history['printer'] ?? [];

        if (_isHistorySame(oldPrinter, newPrinter) &&
            _isHistorySame(oldBtc, btcList) &&
            _isHistorySame(oldEth, ethList)) {
          return; // 數據無變化，跳過重繪
        }
      }

      setState(() {
        _historyMap = {
          ...history,
          'combined': combinedHistory,
        };
        _isLoadingHistory = false;
      });
    }
  }

  void _onPrinterScraped(HyperData data) {
    _apiService.updatePrinter(data);
  }

  void _onRangeScraped(HyperData data) {
    _apiService.updateRange(data);
  }

  void _calculateDeltas(HyperData old, HyperData newData) {
    bool changed = false;
    final bool isBearish = newData.sentiment.contains("跌");
    String? check(double o, double n) => (n - o) != 0 ? _formatDelta(o, n) : null;

    final lD = check(old.longVolNum, newData.longVolNum);
    final sD = check(old.shortVolNum, newData.shortVolNum);
    final double oldPN = isBearish ? (old.shortVolNum - old.longVolNum) : (old.longVolNum - old.shortVolNum);
    final double newPN = isBearish ? (newData.shortVolNum - newData.longVolNum) : (newData.longVolNum - newData.shortVolNum);
    final nD = check(oldPN, newPN);
    if (lD != null || sD != null || nD != null) {
      _lastPrinterLongDelta = lD; _lastPrinterShortDelta = sD; _lastPrinterNetDelta = nD;
      changed = true;
    }

    final blD = check(old.btc?.longVol ?? 0, newData.btc?.longVol ?? 0);
    final bsD = check(old.btc?.shortVol ?? 0, newData.btc?.shortVol ?? 0);
    final double oldBNet = isBearish ? ((old.btc?.shortVol ?? 0) - (old.btc?.longVol ?? 0)) : ((old.btc?.longVol ?? 0) - (old.btc?.shortVol ?? 0));
    final double newBNet = isBearish ? ((newData.btc?.shortVol ?? 0) - (newData.btc?.longVol ?? 0)) : ((newData.btc?.longVol ?? 0) - (newData.btc?.shortVol ?? 0));
    final bnD = check(oldBNet, newBNet);
    if (blD != null || bsD != null || bnD != null) {
      _lastBtcLongDelta = blD; _lastBtcShortDelta = bsD; _lastBtcNetDelta = bnD;
      changed = true;
    }

    final elD = check(old.eth?.longVol ?? 0, newData.eth?.longVol ?? 0);
    final esD = check(old.eth?.shortVol ?? 0, newData.eth?.shortVol ?? 0);
    final double oldENet = isBearish ? ((old.eth?.shortVol ?? 0) - (old.eth?.longVol ?? 0)) : ((old.eth?.longVol ?? 0) - (old.eth?.shortVol ?? 0));
    final double newENet = isBearish ? ((newData.eth?.shortVol ?? 0) - (newData.eth?.longVol ?? 0)) : ((newData.eth?.longVol ?? 0) - (newData.eth?.shortVol ?? 0));
    final enD = check(oldENet, newENet);
    if (elD != null || esD != null || enD != null) {
      _lastEthLongDelta = elD; _lastEthShortDelta = esD; _lastEthNetDelta = enD;
      changed = true;
    }

    final double oldCL = (old.btc?.longVol ?? 0) + (old.eth?.longVol ?? 0);
    final double newCL = (newData.btc?.longVol ?? 0) + (newData.eth?.longVol ?? 0);
    final double oldCS = (old.btc?.shortVol ?? 0) + (old.eth?.shortVol ?? 0);
    final double newCS = (newData.btc?.shortVol ?? 0) + (newData.eth?.shortVol ?? 0);
    final clDelta = check(oldCL, newCL);
    final csDelta = check(oldCS, newCS);
    final double oldCNet = isBearish ? (oldCS - oldCL) : (oldCL - oldCS);
    final double newCNet = isBearish ? (newCS - newCL) : (newCL - newCS);
    final cnDelta = check(oldCNet, newCNet);
    if (clDelta != null || csDelta != null || cnDelta != null) {
      _lastCombinedLongDelta = clDelta; _lastCombinedShortDelta = csDelta; _lastCombinedNetDelta = cnDelta;
      changed = true;
    }

    if (changed) _triggerRainbow();
  }

  void _triggerRainbow() {
    _rainbowTimer?.cancel();
    setState(() => _showRainbow = true);
    _rainbowTimer = Timer(const Duration(seconds: 3), () => setState(() => _showRainbow = false));
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _pollingTimer?.cancel();
    _historyTimer?.cancel();
    _rainbowController.dispose();
    _rainbowTimer?.cancel();
    super.dispose();
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
        body: Center(child: CircularProgressIndicator(color: textGreen, strokeWidth: 3)),
      );
    }

    final bool isBearish = _currentData!.sentiment.contains("跌");
    final Color sColor = isBearish ? textRed : textGreen;
    final cLong = (_currentData!.btc?.longVol ?? 0) + (_currentData!.eth?.longVol ?? 0);
    final cShort = (_currentData!.btc?.shortVol ?? 0) + (_currentData!.eth?.shortVol ?? 0);
    final cNet = isBearish ? (cShort - cLong) : (cLong - cShort);
    final pNet = isBearish ? (_currentData!.shortVolNum - _currentData!.longVolNum) : (_currentData!.longVolNum - _currentData!.shortVolNum);

    return KeyboardListener(
      focusNode: _mainFocusNode,
      autofocus: true,
      onKeyEvent: (event) { if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) _toggleFullscreen(); },
      child: Scaffold(
        backgroundColor: bgDark,
        body: Stack(children: [
          if (defaultTargetPlatform == TargetPlatform.windows)
            Positioned(width: 1, height: 1, child: Opacity(opacity: 0.0, child: CoinglassScraper(onPrinterData: _onPrinterScraped, onRangeData: _onRangeScraped))),

          if (_showRainbow)
            IgnorePointer(child: AnimatedBuilder(
              animation: _rainbowController,
              builder: (c, w) {
                final color = HSVColor.fromAHSV(0.4, (_rainbowController.value * 360), 0.8, 1.0).toColor();
                return Container(decoration: BoxDecoration(border: Border.all(color: color, width: 20)));
              },
            )),

          SafeArea(child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(children: [
              _buildHeader(cardBg),
              const SizedBox(height: 12),
              Expanded(child: Row(children: [
                Expanded(child: _buildColumn(title: "全體印鈔機", icon: Icons.public, accent: Colors.white, bg: cardBg, children: [
                  MetricCard(label: isBearish ? "全體淨空壓" : "全體淨多壓", value: _formatVolume(pNet), delta: _lastPrinterNetDelta, color: sColor, cardBg: Colors.white.withAlpha(5), highlightValue: true, useColorBorder: true),
                  const SizedBox(height: 8),
                  MetricCard(label: "全體總多單", value: _currentData!.longVolDisplay, delta: _lastPrinterLongDelta, color: textGreen, cardBg: Colors.white.withAlpha(2), isSmall: true),
                  const SizedBox(height: 6),
                  MetricCard(label: "全體總空單", value: _currentData!.shortVolDisplay, delta: _lastPrinterShortDelta, color: textRed, cardBg: Colors.white.withAlpha(2), isSmall: true),
                  const SizedBox(height: 10),
                  TugOfWarBar(label: "持倉比例", leftVal: _currentData!.longVolNum, rightVal: _currentData!.shortVolNum, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
                  const SizedBox(height: 10),
                  Expanded(child: _buildChart("全體資金流向", _historyMap['printer']!, isPrinter: true)),
                ])),
                const SizedBox(width: 10),
                Expanded(child: _buildColumn(title: "核心對沖", icon: Icons.layers, accent: Colors.blueAccent, bg: cardBg, children: [
                  MetricCard(label: isBearish ? "對沖淨空壓" : "對沖淨多壓", value: _formatVolume(cNet), delta: _lastCombinedNetDelta, color: sColor, cardBg: Colors.white.withAlpha(5), highlightValue: true, useColorBorder: true),
                  const SizedBox(height: 8),
                  MetricCard(label: "核心總多單", value: _formatVolume(cLong), delta: _lastCombinedLongDelta, color: textGreen, cardBg: Colors.white.withAlpha(2), isSmall: true),
                  const SizedBox(height: 6),
                  MetricCard(label: "核心總空單", value: _formatVolume(cShort), delta: _lastCombinedShortDelta, color: textRed, cardBg: Colors.white.withAlpha(2), isSmall: true),
                  const SizedBox(height: 10),
                  TugOfWarBar(label: "對沖比例", leftVal: cLong, rightVal: cShort, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
                  const SizedBox(height: 10),
                  Expanded(child: _buildChart("對沖淨值趨勢", _historyMap['combined']!, isCombined: true)),
                ])),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: Row(children: [
                  Expanded(child: _buildAssetSub("BTC", const Color(0xFFF7931A), _currentData!.btc, _lastBtcLongDelta, _lastBtcShortDelta, _lastBtcNetDelta, isBearish, cardBg, textGreen, textRed)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildAssetSub("ETH", const Color(0xFF627EEA), _currentData!.eth, _lastEthLongDelta, _lastEthShortDelta, _lastEthNetDelta, isBearish, cardBg, textGreen, textRed)),
                ])),
              ])),
            ])),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader(Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
    child: Row(
      children: [
        const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        const Text("HYPER MONITOR", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(width: 8),
        SentimentBadge(sentiment: _currentData!.sentiment),
        const SizedBox(width: 12),
        Expanded(child: Center(child: _buildRangeSelector())),
        const SizedBox(width: 12),
        if (_lastDataChange != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withAlpha(20),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFFD700).withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: Color(0xFFFFD700), size: 10),
                const SizedBox(width: 4),
                Text("TPE ${DateFormat('HH:mm').format(_lastDataChange!)}",
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildRangeSelector() {
    final ranges = ["1h", "2h", "3h", "4h", "5h", "1d", "2d", "3d", "4d", "5d", "1w", "1m", "3m", "1y"];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Colors.white.withAlpha(5), borderRadius: BorderRadius.circular(6)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ranges.map((r) => GestureDetector(
            onTap: () { setState(() => _selectedRange = r); _loadHistory(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _selectedRange == r ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(4)),
              child: Text(r.toUpperCase(), style: TextStyle(color: _selectedRange == r ? Colors.white : Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildChart(String title, List<HyperData> data, {bool isPrinter = false, bool isCombined = false, bool isBTC = false, bool isETH = false}) {
    if (_isLoadingHistory) return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    return TrendChart(
      title: title,
      displayHistory: data,
      overrideSentiment: _currentData?.sentiment, // 關鍵修正：傳遞全局情緒
      isPrinter: isPrinter,
      isCombined: isCombined,
      isBTC: isBTC,
      isETH: isETH
    );
  }

  Widget _buildAssetSub(String name, Color accent, CoinPosition? pos, String? lDelta, String? sDelta, String? nDelta, bool isBearish, Color bg, Color green, Color red) {
    final double long = pos?.longVol ?? 0;
    final double short = pos?.shortVol ?? 0;
    final double netRaw = isBearish ? (short - long) : (long - short);
    return _buildColumn(title: "$name 監控", icon: Icons.analytics, accent: accent, bg: bg, children: [
      MetricCard(label: isBearish ? "$name 淨空壓" : "$name 淨多壓", value: _formatVolume(netRaw), delta: nDelta, color: isBearish ? red : green, cardBg: Colors.white.withAlpha(5), highlightValue: true, useColorBorder: true),
      const SizedBox(height: 8),
      MetricCard(label: "多單持倉", value: pos?.longDisplay ?? "-", delta: lDelta, color: green, cardBg: Colors.white.withAlpha(2), isSmall: true),
      const SizedBox(height: 6),
      MetricCard(label: "空單持倉", value: pos?.shortDisplay ?? "-", delta: sDelta, color: red, cardBg: Colors.white.withAlpha(2), isSmall: true),
      const SizedBox(height: 10),
      TugOfWarBar(label: "持倉比例", leftVal: long, rightVal: short, leftColor: green, rightColor: red, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
      const SizedBox(height: 10),
      Expanded(child: _buildChart("$name 資金趨勢", _historyMap[name.toLowerCase()]!, isBTC: name == "BTC", isETH: name == "ETH")),
    ]);
  }

  Widget _buildColumn({required String title, required IconData icon, required Color accent, required Color bg, required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Icon(icon, color: accent, size: 14), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))]),
      const Divider(height: 16, color: Colors.white10),
      ...children,
    ]),
  );

  String _formatVolume(double v) {
    String s = v >= 0 ? "+" : ""; double a = v.abs();
    if (a >= 1e8) return "$s\$${(v / 1e8).toStringAsFixed(2)}億";
    if (a >= 1e4) return "$s\$${(v / 1e4).toStringAsFixed(2)}萬";
    return "$s\$${v.toStringAsFixed(0)}";
  }

  String _formatDelta(double o, double n) {
    double d = n - o; double a = d.abs();
    String f = a >= 1e8 ? "${(a/1e8).toStringAsFixed(2)}億" : a >= 1e4 ? "${(a/1e4).toStringAsFixed(0)}萬" : a.toStringAsFixed(0);
    return "${d > 0 ? "+" : "-"}\$$f";
  }

  void _toggleFullscreen() async {
    bool fs = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!fs);
  }
}
