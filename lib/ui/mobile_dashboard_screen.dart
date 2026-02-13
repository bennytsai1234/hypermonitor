import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../core/data_model.dart';
import '../core/data_scraper.dart';
import '../core/api_service.dart';
import 'widgets/sentiment_badge.dart';
import 'widgets/metric_card.dart';
import 'widgets/tug_of_war_bar.dart';
import 'widgets/trend_chart.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  HyperData? _currentData;
  DateTime? _lastDataChange;

  // History (same structure as Windows)
  Map<String, List<HyperData>> _historyMap = {'printer': [], 'btc': [], 'eth': [], 'combined': []};
  String _selectedRange = "1h";
  bool _isLoadingHistory = false;

  Timer? _refreshTimer;
  Timer? _historyTimer;
  late AnimationController _flashController;
  bool _showFlash = false;
  Timer? _flashTimer;

  // History refresh interval (5 minutes, same as Windows/PWA)
  static const _historyRefreshInterval = Duration(minutes: 5);

  // Delta buffers — full 4-asset tracking (same as Windows)
  String? _lastPrinterLongDelta; String? _lastPrinterShortDelta; String? _lastPrinterNetDelta;
  String? _lastBtcLongDelta; String? _lastBtcShortDelta; String? _lastBtcNetDelta;
  String? _lastEthLongDelta; String? _lastEthShortDelta; String? _lastEthNetDelta;
  String? _lastCombinedLongDelta; String? _lastCombinedShortDelta; String? _lastCombinedNetDelta;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _flashController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

    _pollLatest();
    _loadHistory();

    // Poll /latest every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollLatest());
    // Poll /history every 5 minutes (heavy query, reduce DB reads)
    _historyTimer = Timer.periodic(_historyRefreshInterval, (_) => _loadHistory(silent: true));

    // Android: Start foreground service
    if (defaultTargetPlatform == TargetPlatform.android) {
      _startForegroundService();
    }
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: '超級印鈔機 運行中',
      notificationText: '正在監控 Hyperliquid 數據...',
      notificationIcon: null,
      callback: null,
    );
  }

  Future<void> _refreshAll() async {
    await _pollLatest();
    await _loadHistory();
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

  /// Compare two history lists (length + last timestamp)
  bool _isHistorySame(List<HyperData> oldList, List<HyperData> newList) {
    if (oldList.length != newList.length) return false;
    if (oldList.isEmpty) return true;
    return oldList.last.timestamp == newList.last.timestamp;
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoadingHistory = true);
    final history = await _apiService.fetchHistory(_selectedRange);

    // Align and merge BTC + ETH into combined history (same as Windows)
    List<HyperData> combinedHistory = [];
    final btcList = history['btc'] ?? [];
    final ethList = history['eth'] ?? [];
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
      // Silent mode: skip redraw if data unchanged
      if (silent) {
        final oldPrinter = _historyMap['printer'] ?? [];
        final oldBtc = _historyMap['btc'] ?? [];
        final oldEth = _historyMap['eth'] ?? [];
        final newPrinter = history['printer'] ?? [];
        if (_isHistorySame(oldPrinter, newPrinter) &&
            _isHistorySame(oldBtc, btcList) &&
            _isHistorySame(oldEth, ethList)) {
          return; // No change, skip redraw
        }
      }
      setState(() {
        _historyMap = { ...history, 'combined': combinedHistory };
        _isLoadingHistory = false;
      });
    }
  }

  // ===== Scraper callbacks: upload AND update local display =====
  void _onPrinterScraped(HyperData data) {
    _apiService.updatePrinter(data);
    // Also update local display so the telegraph phone shows latest scraped data
    if (mounted) {
      if (_currentData != null) _calculateDeltas(_currentData!, data);
      setState(() {
        _currentData = data;
        _lastDataChange = DateTime.now().toTaiwanTime();
      });
    }
  }

  void _onRangeScraped(HyperData data) {
    _apiService.updateRange(data);
    // Merge range data (BTC/ETH) into current display
    if (mounted && _currentData != null) {
      final merged = HyperData(
        timestamp: _currentData!.timestamp,
        walletCount: _currentData!.walletCount,
        profitCount: _currentData!.profitCount,
        lossCount: _currentData!.lossCount,
        longVolDisplay: _currentData!.longVolDisplay,
        shortVolDisplay: _currentData!.shortVolDisplay,
        netVolDisplay: _currentData!.netVolDisplay,
        sentiment: _currentData!.sentiment,
        longVolNum: _currentData!.longVolNum,
        shortVolNum: _currentData!.shortVolNum,
        netVolNum: _currentData!.netVolNum,
        btc: data.btc ?? _currentData!.btc,
        eth: data.eth ?? _currentData!.eth,
      );
      setState(() => _currentData = merged);
    }
  }

  // ===== Full 4-asset delta calculation (same as Windows) =====
  void _calculateDeltas(HyperData old, HyperData newData) {
    bool changed = false;
    final bool isBearish = newData.sentiment.contains("跌");
    String? check(double o, double n) => (n - o) != 0 ? _formatDelta(o, n) : null;

    // Printer (all)
    final lD = check(old.longVolNum, newData.longVolNum);
    final sD = check(old.shortVolNum, newData.shortVolNum);
    final double oldPN = isBearish ? (old.shortVolNum - old.longVolNum) : (old.longVolNum - old.shortVolNum);
    final double newPN = isBearish ? (newData.shortVolNum - newData.longVolNum) : (newData.longVolNum - newData.shortVolNum);
    final nD = check(oldPN, newPN);
    if (lD != null || sD != null || nD != null) {
      _lastPrinterLongDelta = lD; _lastPrinterShortDelta = sD; _lastPrinterNetDelta = nD;
      changed = true;
    }

    // BTC
    final blD = check(old.btc?.longVol ?? 0, newData.btc?.longVol ?? 0);
    final bsD = check(old.btc?.shortVol ?? 0, newData.btc?.shortVol ?? 0);
    final double oldBNet = isBearish ? ((old.btc?.shortVol ?? 0) - (old.btc?.longVol ?? 0)) : ((old.btc?.longVol ?? 0) - (old.btc?.shortVol ?? 0));
    final double newBNet = isBearish ? ((newData.btc?.shortVol ?? 0) - (newData.btc?.longVol ?? 0)) : ((newData.btc?.longVol ?? 0) - (newData.btc?.shortVol ?? 0));
    final bnD = check(oldBNet, newBNet);
    if (blD != null || bsD != null || bnD != null) {
      _lastBtcLongDelta = blD; _lastBtcShortDelta = bsD; _lastBtcNetDelta = bnD;
      changed = true;
    }

    // ETH
    final elD = check(old.eth?.longVol ?? 0, newData.eth?.longVol ?? 0);
    final esD = check(old.eth?.shortVol ?? 0, newData.eth?.shortVol ?? 0);
    final double oldENet = isBearish ? ((old.eth?.shortVol ?? 0) - (old.eth?.longVol ?? 0)) : ((old.eth?.longVol ?? 0) - (old.eth?.shortVol ?? 0));
    final double newENet = isBearish ? ((newData.eth?.shortVol ?? 0) - (newData.eth?.longVol ?? 0)) : ((newData.eth?.longVol ?? 0) - (newData.eth?.shortVol ?? 0));
    final enD = check(oldENet, newENet);
    if (elD != null || esD != null || enD != null) {
      _lastEthLongDelta = elD; _lastEthShortDelta = esD; _lastEthNetDelta = enD;
      changed = true;
    }

    // Combined (BTC + ETH)
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

    if (changed) _triggerFlash();
  }

  void _triggerFlash() {
    _flashTimer?.cancel();
    setState(() => _showFlash = true);
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showFlash = false);
    });
  }

  String _formatDelta(double o, double n) {
    double d = n - o; double a = d.abs();
    String f = a >= 1e8 ? "${(a / 1e8).toStringAsFixed(2)}億" : a >= 1e4 ? "${(a / 1e4).toStringAsFixed(0)}萬" : a.toStringAsFixed(0);
    return "${d > 0 ? "+" : "-"}\$$f";
  }

  String _formatVolume(double v) {
    String s = v >= 0 ? "+" : ""; double a = v.abs();
    if (a >= 1e8) return "$s\$${(v / 1e8).toStringAsFixed(2)}億";
    if (a >= 1e4) return "$s\$${(v / 1e4).toStringAsFixed(2)}萬";
    return "$s\$${v.toStringAsFixed(0)}";
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _refreshTimer?.cancel();
    _historyTimer?.cancel();
    _flashController.dispose();
    _flashTimer?.cancel();
    if (defaultTargetPlatform == TargetPlatform.android) {
      FlutterForegroundTask.stopService();
    }
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
        body: Stack(
          children: [
            // Scraper must exist during loading too
            Opacity(
              opacity: 0.0,
              child: SizedBox(
                width: 1, height: 1,
                child: CoinglassScraper(onPrinterData: _onPrinterScraped, onRangeData: _onRangeScraped),
              ),
            ),
            const Center(child: CircularProgressIndicator(color: textGreen)),
          ],
        ),
      );
    }

    final bool isBearish = _currentData!.sentiment.contains("跌");
    final Color sColor = isBearish ? textRed : textGreen;

    // Computed values
    final double pNet = isBearish ? (_currentData!.shortVolNum - _currentData!.longVolNum) : (_currentData!.longVolNum - _currentData!.shortVolNum);
    final double cLong = (_currentData!.btc?.longVol ?? 0) + (_currentData!.eth?.longVol ?? 0);
    final double cShort = (_currentData!.btc?.shortVol ?? 0) + (_currentData!.eth?.shortVol ?? 0);
    final double cNet = isBearish ? (cShort - cLong) : (cLong - cShort);

    return WithForegroundTask(child: Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. Hidden scraper (telegraph)
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 1, height: 1,
              child: CoinglassScraper(onPrinterData: _onPrinterScraped, onRangeData: _onRangeScraped),
            ),
          ),

          // 2. Main Content
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: cardBg,
              elevation: 0,
              titleSpacing: 12,
              title: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  const Text("HYPER MOBILE", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const Spacer(),
                  if (_lastDataChange != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFD700).withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, color: Color(0xFFFFD700), size: 10),
                          const SizedBox(width: 3),
                          Text(DateFormat('HH:mm').format(_lastDataChange!),
                            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  SentimentBadge(sentiment: _currentData!.sentiment),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: _buildRangeSelector(),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: _refreshAll,
              color: textGreen,
              backgroundColor: const Color(0xFF1A1A1A),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ========== Section 1: 全體印鈔機 ==========
                    _buildSectionHeader("全體印鈔機", Icons.public, Colors.white),
                    const SizedBox(height: 8),
                    MetricCard(
                      label: isBearish ? "全體淨空壓" : "全體淨多壓",
                      value: _formatVolume(pNet),
                      delta: _lastPrinterNetDelta,
                      color: sColor,
                      cardBg: Colors.white.withAlpha(10),
                      highlightValue: true,
                      useColorBorder: true,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: MetricCard(label: "全體總多單", value: _currentData!.longVolDisplay, delta: _lastPrinterLongDelta, color: textGreen, cardBg: Colors.white.withAlpha(5), isSmall: true)),
                      const SizedBox(width: 8),
                      Expanded(child: MetricCard(label: "全體總空單", value: _currentData!.shortVolDisplay, delta: _lastPrinterShortDelta, color: textRed, cardBg: Colors.white.withAlpha(5), isSmall: true)),
                    ]),
                    const SizedBox(height: 10),
                    TugOfWarBar(label: "持倉比例", leftVal: _currentData!.longVolNum, rightVal: _currentData!.shortVolNum, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
                    const SizedBox(height: 8),
                    SizedBox(height: 220, child: _buildChart("全體資金流向", _historyMap['printer']!, isPrinter: true)),

                    const SizedBox(height: 20),
                    // ========== Section 2: 核心對沖 ==========
                    _buildSectionHeader("核心對沖", Icons.layers, Colors.blueAccent),
                    const SizedBox(height: 8),
                    MetricCard(
                      label: isBearish ? "對沖淨空壓" : "對沖淨多壓",
                      value: _formatVolume(cNet),
                      delta: _lastCombinedNetDelta,
                      color: sColor,
                      cardBg: Colors.white.withAlpha(10),
                      highlightValue: true,
                      useColorBorder: true,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: MetricCard(label: "核心總多單", value: _formatVolume(cLong), delta: _lastCombinedLongDelta, color: textGreen, cardBg: Colors.white.withAlpha(5), isSmall: true)),
                      const SizedBox(width: 8),
                      Expanded(child: MetricCard(label: "核心總空單", value: _formatVolume(cShort), delta: _lastCombinedShortDelta, color: textRed, cardBg: Colors.white.withAlpha(5), isSmall: true)),
                    ]),
                    const SizedBox(height: 10),
                    TugOfWarBar(label: "對沖比例", leftVal: cLong, rightVal: cShort, leftColor: textGreen, rightColor: textRed, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
                    const SizedBox(height: 8),
                    SizedBox(height: 220, child: _buildChart("對沖淨值趨勢", _historyMap['combined']!, isCombined: true)),

                    const SizedBox(height: 20),
                    // ========== Section 3: BTC ==========
                    _buildAssetSection("BTC", const Color(0xFFF7931A), _currentData!.btc,
                      _lastBtcLongDelta, _lastBtcShortDelta, _lastBtcNetDelta,
                      isBearish, textGreen, textRed),

                    const SizedBox(height: 20),
                    // ========== Section 4: ETH ==========
                    _buildAssetSection("ETH", const Color(0xFF627EEA), _currentData!.eth,
                      _lastEthLongDelta, _lastEthShortDelta, _lastEthNetDelta,
                      isBearish, textGreen, textRed),

                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        "最後更新: ${DateFormat('HH:mm:ss').format(_currentData!.timestamp)}",
                        style: const TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // 3. Alert flash layer
          if (_showFlash)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashController,
                builder: (context, child) {
                  final color = HSVColor.fromAHSV(0.3, (_flashController.value * 360), 0.8, 1.0).toColor();
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 12),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ));
  }

  // ====== Section Header ======
  Widget _buildSectionHeader(String title, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Icon(icon, color: accent, size: 14),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  // ====== Asset Section (BTC / ETH) ======
  Widget _buildAssetSection(String name, Color accent, CoinPosition? pos,
      String? lDelta, String? sDelta, String? nDelta,
      bool isBearish, Color green, Color red) {
    final double long = pos?.longVol ?? 0;
    final double short = pos?.shortVol ?? 0;
    final double netRaw = isBearish ? (short - long) : (long - short);
    final Color sColor = isBearish ? red : green;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildSectionHeader("$name 監控", Icons.analytics, accent),
      const SizedBox(height: 8),
      MetricCard(
        label: isBearish ? "$name 淨空壓" : "$name 淨多壓",
        value: _formatVolume(netRaw),
        delta: nDelta,
        color: sColor,
        cardBg: Colors.white.withAlpha(10),
        highlightValue: true,
        useColorBorder: true,
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: MetricCard(label: "多單持倉", value: pos?.longDisplay ?? "-", delta: lDelta, color: green, cardBg: Colors.white.withAlpha(5), isSmall: true)),
        const SizedBox(width: 8),
        Expanded(child: MetricCard(label: "空單持倉", value: pos?.shortDisplay ?? "-", delta: sDelta, color: red, cardBg: Colors.white.withAlpha(5), isSmall: true)),
      ]),
      const SizedBox(height: 10),
      TugOfWarBar(label: "持倉比例", leftVal: long, rightVal: short, leftColor: green, rightColor: red, leftLabel: "多", rightLabel: "空", cardBg: Colors.transparent),
      const SizedBox(height: 8),
      SizedBox(
        height: 220,
        child: _buildChart("$name 資金趨勢", _historyMap[name.toLowerCase()] ?? [], isBTC: name == "BTC", isETH: name == "ETH"),
      ),
    ]);
  }

  // ====== Chart Builder ======
  Widget _buildChart(String title, List<HyperData> data, {bool isPrinter = false, bool isCombined = false, bool isBTC = false, bool isETH = false}) {
    if (_isLoadingHistory) return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
    return TrendChart(
      title: title,
      displayHistory: data,
      overrideSentiment: _currentData?.sentiment,
      isPrinter: isPrinter,
      isCombined: isCombined,
      isBTC: isBTC,
      isETH: isETH,
    );
  }

  // ====== Range Selector (14 options, same as Windows) ======
  Widget _buildRangeSelector() {
    final ranges = ["1h", "2h", "3h", "4h", "5h", "1d", "2d", "3d", "4d", "5d", "1w", "1m", "3m", "1y"];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ranges.map((r) => GestureDetector(
            onTap: () { setState(() => _selectedRange = r); _loadHistory(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _selectedRange == r ? Colors.blueAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(r.toUpperCase(), style: TextStyle(color: _selectedRange == r ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
