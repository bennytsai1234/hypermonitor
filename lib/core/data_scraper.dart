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
    Future.delayed(const Duration(seconds: 5), () => _startScrapingLoop());
  }

  WebViewController _createMobileController(String url) {
    return WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted)..loadRequest(Uri.parse(url));
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
    _scrapeTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _doScrapes());
  }

  Future<void> _doScrapes() async {
    final printerResult = await _executeScrape(_winA, _mobileA, _printerJs);
    if (kDebugMode) print("RAW PRINTER: $printerResult");
    if (printerResult != null && printerResult != "null") {
      final data = _parsePrinterJson(printerResult);
      if (data != null) widget.onPrinterData(data);
    }

    final rangeResult = await _executeScrape(_winB, _mobileB, _rangeJs);
    if (kDebugMode) print("RAW RANGE: $rangeResult");
    if (rangeResult != null && rangeResult != "null") {
      final data = _parseRangeJson(rangeResult);
      if (data != null) widget.onRangeData(data);
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
        if (s.startsWith('"') && s.endsWith('"')) s = s.substring(1, s.length - 1);
        return s.replaceAll(r'\"', '"');
      }
    } catch (e) { return null; }
  }

  static const _printerJs = r"""
    (function() {
      const rows = document.querySelectorAll('tr');
      for (const row of rows) {
        const text = row.innerText;
        if (text.includes('超级印钞機') || text.includes('超級印鈔機') || text.includes('超级印钞机')) {
          const cells = row.querySelectorAll('td');
          if (cells.length < 8) continue;
          
          // 針對用戶提供的新 HTML 結構精確定位
          const volDivs = cells[4].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
          const plDivs = cells[7].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
          const sentimentBtn = row.querySelector('button.tag-but'); // 直接找情緒按鈕
          
          return JSON.stringify({
            found: true,
            walletCount: cells[2].innerText.trim(),
            longVol: volDivs[0] ? volDivs[0].innerText.trim() : "0",
            shortVol: volDivs[1] ? volDivs[1].innerText.trim() : "0",
            netVol: cells[5].innerText.trim(),
            profitCount: plDivs[0] ? plDivs[0].innerText.trim() : "0",
            lossCount: plDivs[1] ? plDivs[1].innerText.trim() : "0",
            sentiment: sentimentBtn ? sentimentBtn.innerText.trim() : ""
          });
        }
      }
      return null;
    })();
  """;

  static const _rangeJs = r"""
    (function() {
      const allDivs = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
      let data = { btc: null, eth: null };
      for (const row of allDivs) {
        const text = row.innerText;
        let symbol = "";
        if (text.includes('BTC') && !text.includes('WBTC')) symbol = "BTC";
        else if (text.includes('ETH') && !text.includes('WETH')) symbol = "ETH";
        
        if (symbol) {
          const amounts = row.querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by, div.Number');
          if (amounts.length >= 2) {
            data[symbol.toLowerCase()] = {
              symbol: symbol,
              long: amounts[0].innerText.trim(),
              short: amounts[1].innerText.trim(),
              total: amounts[amounts.length - 1].innerText.trim()
            };
          }
        }
      }
      return JSON.stringify(data);
    })();
  """;

  HyperData? _parsePrinterJson(String raw) {
    try {
      final d = jsonDecode(_cleanJson(raw));
      _lastHyperData = HyperData(
        timestamp: DateTime.now(),
        walletCount: _toInt(d['walletCount']),
        openPositionCount: 0, openPositionPct: "", 
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
      return _lastHyperData;
    } catch (e) { return null; }
  }

  HyperData? _parseRangeJson(String raw) {
    try {
      final d = jsonDecode(_cleanJson(raw));
      final btc = d['btc'] != null ? _toCoinPos(d['btc']) : _lastHyperData?.btc;
      final eth = d['eth'] != null ? _toCoinPos(d['eth']) : _lastHyperData?.eth;
      
      _lastHyperData = HyperData(
        timestamp: _lastHyperData?.timestamp ?? DateTime.now(),
        walletCount: _lastHyperData?.walletCount ?? 0,
        openPositionCount: 0, openPositionPct: "", 
        profitCount: _lastHyperData?.profitCount ?? 0,
        lossCount: _lastHyperData?.lossCount ?? 0,
        longVolDisplay: _lastHyperData?.longVolDisplay ?? "",
        shortVolDisplay: _lastHyperData?.shortVolDisplay ?? "",
        netVolDisplay: _lastHyperData?.netVolDisplay ?? "",
        sentiment: _lastHyperData?.sentiment ?? "",
        longVolNum: _lastHyperData?.longVolNum ?? 0,
        shortVolNum: _lastHyperData?.shortVolNum ?? 0,
        netVolNum: _lastHyperData?.netVolNum ?? 0,
        btc: btc, eth: eth,
      );
      return _lastHyperData;
    } catch (e) { return null; }
  }

  CoinPosition _toCoinPos(Map<String, dynamic> d) {
    final l = _parseValue(d['long']);
    final s = _parseValue(d['short']);
    final net = l - s;
    return CoinPosition(
      symbol: d['symbol'], longVol: l, shortVol: s, totalVol: _parseValue(d['total']), netVol: net,
      longDisplay: _toTC(d['long']), shortDisplay: _toTC(d['short']), totalDisplay: _toTC(d['total']),
      netDisplay: (net >= 0 ? "+" : "") + (net.abs() >= 1e8 ? "${(net / 1e8).toStringAsFixed(2)}億" : "${(net / 1e4).toStringAsFixed(0)}萬"),
    );
  }

  String _toTC(String s) => s.replaceAll('超级', '超級').replaceAll('印钞机', '印鈔機').replaceAll('亿', '億').replaceAll('万', '萬').replaceAll('涨', '漲').replaceAll('强', '強').replaceAll('势', '勢').replaceAll('态', '態').replaceAll('观', '觀').replaceAll('亏', '虧');
  int _toInt(dynamic v) => int.tryParse(v.toString().replaceAll(',', '').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  String _cleanJson(String s) => (s.startsWith('"') && s.endsWith('"')) ? s.substring(1, s.length - 1).replaceAll(r'\"', '"') : s;
  
  double _parseValue(String raw) {
    try {
      String clean = raw.replaceAll(RegExp(r'[\$¥,]'), '').trim();
      double multiplier = 1.0;
      if (clean.contains('億') || clean.contains('B') || clean.contains('亿')) { multiplier = 1e8; clean = clean.replaceAll(RegExp(r'[億B亿]'), ''); }
      else if (clean.contains('萬') || clean.contains('M') || clean.contains('万')) { multiplier = 1e4; clean = clean.replaceAll(RegExp(r'[萬M万]'), ''); }
      return (double.tryParse(clean) ?? 0.0) * multiplier;
    } catch (e) { return 0.0; }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
    SizedBox(width: 1, height: 1, child: defaultTargetPlatform == TargetPlatform.windows ? (_isWinAInit ? win.Webview(_winA) : Container()) : (Container())),
    SizedBox(width: 1, height: 1, child: defaultTargetPlatform == TargetPlatform.windows ? (_isWinBInit ? win.Webview(_winB) : Container()) : (Container())),
  ]);

  @override
  void dispose() { _scrapeTimer?.cancel(); _winA.dispose(); _winB.dispose(); super.dispose(); }
}