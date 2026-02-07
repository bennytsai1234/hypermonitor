import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'data_model.dart';

class CoinglassScraper extends StatefulWidget {
  final Function(HyperData) onPrinterData; 
  final Function(HyperData) onRangeData;   

  const CoinglassScraper({
    super.key, 
    required this.onPrinterData,
    required this.onRangeData,
  });

  @override
  State<CoinglassScraper> createState() => _CoinglassScraperState();
}

class _CoinglassScraperState extends State<CoinglassScraper> {
  WebViewController? _mobileA;
  final _winA = win.WebviewController();
  bool _isWinAInit = false;

  WebViewController? _mobileB;
  final _winB = win.WebviewController();
  bool _isWinBInit = false;

  Timer? _scrapeTimer;
  HyperData? _lastHyperData;

  @override
  void initState() {
    super.initState();
    _initWebviews();
  }

  void _initWebviews() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _initWindowsWebview(_winA, 'https://www.coinglass.com/zh/hl', (ok) => setState(() => _isWinAInit = ok));
      _initWindowsWebview(_winB, 'https://www.coinglass.com/zh/hl/range/9', (ok) => setState(() => _isWinBInit = ok));
    } else {
      _mobileA = _createMobileController('https://www.coinglass.com/zh/hl');
      _mobileB = _createMobileController('https://www.coinglass.com/zh/hl/range/9');
    }
    
    Future.delayed(const Duration(seconds: 5), () {
      _startScrapingLoop();
    });
  }

  WebViewController _createMobileController(String url) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  Future<void> _initWindowsWebview(win.WebviewController ctrl, String url, Function(bool) onInit) async {
    try {
      await ctrl.initialize();
      await ctrl.setBackgroundColor(Colors.transparent);
      await ctrl.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
      await ctrl.loadUrl(url);
      onInit(true);
    } catch (e) { }
  }

  void _startScrapingLoop() {
    _doScrapes();
    _scrapeTimer?.cancel();
    _scrapeTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      _doScrapes();
    });
  }

  Future<void> _doScrapes() async {
    // 1. 全體數據抓取
    final printerResult = await _executeScrape(_winA, _mobileA, _printerJs);
    if (kDebugMode && printerResult != null) print("RAW PRINTER: $printerResult");
    if (printerResult != null && printerResult != "null") {
      _parsePrinter(printerResult);
      if (_lastHyperData != null) widget.onPrinterData(_lastHyperData!);
    }

    // 2. 詳細數據抓取 (使用新版精確邏輯)
    final rangeResult = await _executeScrape(_winB, _mobileB, _rangeJs);
    if (kDebugMode && rangeResult != null) print("RAW RANGE: $rangeResult");
    if (rangeResult != null && rangeResult != "null") {
      _parseRange(rangeResult);
      if (_lastHyperData != null) widget.onRangeData(_lastHyperData!);
    }
  }

  Future<String?> _executeScrape(win.WebviewController? winCtrl, WebViewController? mobCtrl, String js) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        if (winCtrl == null) return null;
        await winCtrl.reload();
        await Future.delayed(const Duration(seconds: 5));
        return await winCtrl.executeScript(js);
      } else {
        if (mobCtrl == null) return null;
        await mobCtrl.reload();
        await Future.delayed(const Duration(seconds: 5));
        final res = await mobCtrl.runJavaScriptReturningResult(js);
        String s = res.toString();
        if (s.startsWith('"') || s.startsWith("'")) s = s.substring(1, s.length - 1);
        return s.replaceAll(r'\"', '"');
      }
    } catch (e) { return null; }
  }

  static const _printerJs = r"""
    (function() {
      const rows = document.querySelectorAll('tr');
      for (const row of rows) {
        const text = row.innerText;
        if (text.includes('超级印钞机') || text.includes('超級印鈔機') || text.includes('Super Money Printer')) {
          const cells = row.querySelectorAll('td');
          if (cells.length < 8) return null;
          const volParts = cells[4].innerText.trim().split('\n');
          const plParts = cells[6].innerText.trim().split('\n');
          return JSON.stringify({
            walletCount: cells[2].innerText.trim(),
            openPositionCount: cells[3].innerText.trim().replace(/\(.*\)/, '').trim(),
            openPositionPct: (cells[3].innerText.match(/\((\d+\.?\d*%)\)/) || [])[1] || "",
            longVol: volParts[0] || "0",
            shortVol: volParts[1] || "0",
            netVol: cells[5].innerText.trim(),
            profitCount: plParts[0] || "0",
            lossCount: plParts[1] || "0",
            sentiment: cells[7].innerText.trim()
          });
        }
      }
      return null;
    })();
  """;

  // --- 改進版 Range JS：精確定位表格單元格，避開價格干擾 ---
  static const _rangeJs = r"""
    (function() {
      const rows = document.querySelectorAll('tr');
      let data = { btc: null, eth: null };
      
      for (const row of rows) {
        const cells = row.querySelectorAll('td');
        if (cells.length < 6) continue;
        
        const name = cells[0].innerText.toUpperCase();
        let symbol = "";
        if (name.includes('BTC') && !name.includes('WBTC')) symbol = "BTC";
        else if (name.includes('ETH') && !name.includes('WETH')) symbol = "ETH";
        
        if (symbol && !data[symbol.toLowerCase()]) {
          // 在策略詳情頁中：
          // cells[1] = 價格
          // cells[2] = 24h漲跌
          // cells[3] = 多單持倉 (Long OI)
          // cells[4] = 空單持倉 (Short OI)
          // cells[5] = 淨持倉
          data[symbol.toLowerCase()] = {
            symbol: symbol,
            long: cells[3].innerText.trim(),
            short: cells[4].innerText.trim(),
            total: cells[5].innerText.trim()
          };
        }
      }
      return JSON.stringify(data);
    })();
  """;

  void _parsePrinter(String raw) {
    try {
      final d = jsonDecode(_cleanJson(raw));
      _lastHyperData = HyperData(
        timestamp: DateTime.now(),
        walletCount: _toInt(d['walletCount']),
        openPositionCount: _toInt(d['openPositionCount']),
        openPositionPct: d['openPositionPct'],
        profitCount: _toInt(d['profitCount']),
        lossCount: _toInt(d['lossCount']),
        longVolDisplay: _toTC(d['longVol']),
        shortVolDisplay: _toTC(d['shortVol']),
        netVolDisplay: _toTC(d['netVol']),
        sentiment: _toTC(d['sentiment']),
        longVolNum: _parseValue(d['longVol']),
        shortVolNum: _parseValue(d['shortVol']),
        netVolNum: _parseValue(d['netVol']),
        btc: _lastHyperData?.btc,
        eth: _lastHyperData?.eth,
      );
    } catch (e) { }
  }

  void _parseRange(String raw) {
    try {
      final d = jsonDecode(_cleanJson(raw));
      final btc = d['btc'] != null ? _toCoinPos(d['btc']) : _lastHyperData?.btc;
      final eth = d['eth'] != null ? _toCoinPos(d['eth']) : _lastHyperData?.eth;
      
      _lastHyperData = HyperData(
        timestamp: _lastHyperData?.timestamp ?? DateTime.now(),
        walletCount: _lastHyperData?.walletCount ?? 0,
        openPositionCount: _lastHyperData?.openPositionCount ?? 0,
        openPositionPct: _lastHyperData?.openPositionPct ?? "",
        profitCount: _lastHyperData?.profitCount ?? 0,
        lossCount: _lastHyperData?.lossCount ?? 0,
        longVolDisplay: _lastHyperData?.longVolDisplay ?? "",
        shortVolDisplay: _lastHyperData?.shortVolDisplay ?? "",
        netVolDisplay: _lastHyperData?.netVolDisplay ?? "",
        sentiment: _lastHyperData?.sentiment ?? "",
        longVolNum: _lastHyperData?.longVolNum ?? 0,
        shortVolNum: _lastHyperData?.shortVolNum ?? 0,
        netVolNum: _lastHyperData?.netVolNum ?? 0,
        btc: btc,
        eth: eth,
      );
    } catch (e) { }
  }

  CoinPosition _toCoinPos(Map<String, dynamic> d) {
    final l = _parseValue(d['long']);
    final s = _parseValue(d['short']);
    final net = l - s;
    final String netStr = (net >= 0 ? "+" : "") + 
        (net.abs() >= 1e8 ? "${(net / 1e8).toStringAsFixed(2)}億" : "${(net / 1e4).toStringAsFixed(0)}萬");

    return CoinPosition(
      symbol: d['symbol'], 
      longVol: l, 
      shortVol: s, 
      totalVol: _parseValue(d['total']),
      netVol: net,
      longDisplay: _toTC(d['long']), 
      shortDisplay: _toTC(d['short']), 
      totalDisplay: _toTC(d['total']),
      netDisplay: netStr,
    );
  }

  String _toTC(String s) {
    return s.replaceAll('超级', '超級').replaceAll('印钞机', '印鈔機')
            .replaceAll('亿', '億').replaceAll('万', '萬').replaceAll('涨', '漲')
            .replaceAll('强', '強').replaceAll('势', '勢').replaceAll('态', '態')
            .replaceAll('观', '觀').replaceAll('亏', '虧');
  }

  int _toInt(dynamic v) => int.tryParse(v.toString().replaceAll(',', '')) ?? 0;

  String _cleanJson(String s) {
    if (s.startsWith('"') && s.endsWith('"')) s = s.substring(1, s.length - 1).replaceAll(r'\"', '"');
    return s.replaceAll(r'\\', r'\');
  }

  double _parseValue(String raw) {
    try {
      String clean = raw.replaceAll(RegExp(r'[\$¥,]'), '').trim();
      double multiplier = 1.0;
      if (clean.contains('億') || clean.contains('億') || clean.contains('B')) { 
        multiplier = 100000000.0; 
        clean = clean.replaceAll(RegExp(r'[億億B]'), ''); 
      }
      else if (clean.contains('萬') || clean.contains('萬') || clean.contains('M')) { 
        multiplier = 10000.0; 
        clean = clean.replaceAll(RegExp(r'[萬萬M]'), ''); 
      }
      // 處理可能的簡體字備份
      clean = clean.replaceAll('亿', '').replaceAll('万', '');
      return (double.tryParse(clean) ?? 0.0) * multiplier;
    } catch (e) { return 0.0; }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildWebviewItem(_winA, _mobileA, _isWinAInit),
        _buildWebviewItem(_winB, _mobileB, _isWinBInit),
      ],
    );
  }

  Widget _buildWebviewItem(win.WebviewController winCtrl, WebViewController? mobCtrl, bool isWinInit) {
    return SizedBox(
      width: 1, height: 1,
      child: defaultTargetPlatform == TargetPlatform.windows
          ? (isWinInit ? win.Webview(winCtrl) : Container())
          : (mobCtrl != null ? WebViewWidget(controller: mobCtrl) : Container()),
    );
  }

  @override
  void dispose() {
    _scrapeTimer?.cancel();
    _winA.dispose();
    _winB.dispose();
    super.dispose();
  }
}
