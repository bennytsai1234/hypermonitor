import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
  List<HyperData> _printerHistory = [];
  String _selectedRange = "1h";

  Timer? _refreshTimer;
  late AnimationController _flashController;
  bool _showFlash = false;
  Timer? _flashTimer;

  // Delta
  String? _lastNetDelta;
  String? _lastLongDelta;
  String? _lastShortDelta;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // 保持螢幕常亮，確保爬蟲持續運行
    _flashController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _refreshAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollLatest());
  }

  Future<void> _refreshAll() async {
    await _pollLatest();
    await _loadHistory();
  }

  Future<void> _pollLatest() async {
    final newData = await _apiService.fetchLatest();
    if (newData == null) return;
    if (_currentData != null) _calculateDeltas(_currentData!, newData);
    if (mounted) setState(() => _currentData = newData);
  }

  Future<void> _loadHistory() async {
    final history = await _apiService.fetchHistory(_selectedRange);
    if (mounted) setState(() => _printerHistory = history['printer'] ?? []);
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
      _lastLongDelta = lD;
      _lastShortDelta = sD;
      _lastNetDelta = nD;
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
    double d = n - o;
    double a = d.abs();
    String f = a >= 1e8
        ? "${(a / 1e8).toStringAsFixed(2)}億"
        : a >= 1e4
            ? "${(a / 1e4).toStringAsFixed(0)}萬"
            : a.toStringAsFixed(0);
    return "${d > 0 ? "+" : "-"}\$$f";
  }

  void _onPrinterScraped(HyperData data) {
    _apiService.updatePrinter(data);
    // 可選：本地也更新顯示，讓掛機手機也能看到最新數據
    if (mounted) setState(() => _currentData = data);
  }

  void _onRangeScraped(HyperData data) {
    _apiService.updateRange(data);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _refreshTimer?.cancel();
    _flashController.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF000000);
    const textGreen = Color(0xFF00FF9D);
    const textRed = Color(0xFFFF2E2E);

    if (_currentData == null) {
      return Scaffold(
        backgroundColor: bgDark,
        body: Stack(
          children: [
            // 隱藏的 Scraper (必須在 Loading 時也存在，否則無法開始抓取)
            Opacity(
              opacity: 0.0,
              child: SizedBox(
                width: 1, height: 1,
                child: CoinglassScraper(onPrinterData: _onPrinterScraped, onRangeData: _onRangeScraped)
              ),
            ),
            const Center(child: CircularProgressIndicator(color: textGreen)),
          ],
        ),
      );
    }

    final bool isBearish = _currentData!.sentiment.contains("跌");
    final Color sColor = isBearish ? textRed : textGreen;
    final double netVal = isBearish ? (_currentData!.shortVolNum - _currentData!.longVolNum) : (_currentData!.longVolNum - _currentData!.shortVolNum);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. 背景執行爬蟲 (Hidden)
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: CoinglassScraper(
                onPrinterData: _onPrinterScraped,
                onRangeData: _onRangeScraped
              )
            ),
          ),

          // 2. Main Content
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: const Color(0xFF080808),
              elevation: 0,
              title: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text("HYPER MOBILE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const Spacer(),
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
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 核心淨壓卡片
                    MetricCard(
                      label: isBearish ? "全體淨空壓" : "全體淨多壓",
                      value: _formatVolume(netVal),
                      delta: _lastNetDelta,
                      color: sColor,
                      cardBg: Colors.white.withAlpha(10),
                      highlightValue: true,
                      useColorBorder: true,
                    ),
                    const SizedBox(height: 16),

                    // 多空詳細
                    Row(
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: "總多單",
                            value: _currentData!.longVolDisplay,
                            delta: _lastLongDelta,
                            color: textGreen,
                            cardBg: Colors.white.withAlpha(5),
                            isSmall: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MetricCard(
                            label: "總空單",
                            value: _currentData!.shortVolDisplay,
                            delta: _lastShortDelta,
                            color: textRed,
                            cardBg: Colors.white.withAlpha(5),
                            isSmall: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 持倉比例
                    TugOfWarBar(
                      label: "市場持倉比例",
                      leftVal: _currentData!.longVolNum,
                      rightVal: _currentData!.shortVolNum,
                      leftColor: textGreen,
                      rightColor: textRed,
                      leftLabel: "多",
                      rightLabel: "空",
                      cardBg: Colors.white.withAlpha(5),
                    ),
                    const SizedBox(height: 24),

                    // 趨勢圖
                    const Text("全體資金流向趨勢", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 280,
                      child: TrendChart(
                        title: "",
                        displayHistory: _printerHistory,
                        overrideSentiment: _currentData?.sentiment,
                        isPrinter: true,
                      ),
                    ),

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

          // 3. 警報閃爍層
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
    );
  }

  Widget _buildRangeSelector() {
    final ranges = ["1h", "4h", "1d", "1w"];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ranges.map((r) => GestureDetector(
          onTap: () { setState(() => _selectedRange = r); _loadHistory(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: _selectedRange == r ? Colors.blueAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(r.toUpperCase(), style: TextStyle(color: _selectedRange == r ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        )).toList(),
      ),
    );
  }

  String _formatVolume(double v) {
    String s = v >= 0 ? "+" : ""; double a = v.abs();
    if (a >= 1e8) return "$s\$${(v / 1e8).toStringAsFixed(2)}億";
    if (a >= 1e4) return "$s\$${(v / 1e4).toStringAsFixed(2)}萬";
    return "$s\$${v.toStringAsFixed(0)}";
  }
}
