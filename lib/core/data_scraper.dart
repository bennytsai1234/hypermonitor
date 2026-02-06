import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'data_model.dart';

class CoinglassScraper extends StatefulWidget {
  final Function(HyperData) onDataScraped;

  const CoinglassScraper({super.key, required this.onDataScraped});

  @override
  State<CoinglassScraper> createState() => _CoinglassScraperState();
}

class _CoinglassScraperState extends State<CoinglassScraper> {
  // Webview A: Printer
  WebViewController? _mobileA;
  final _winA = win.WebviewController();
  bool _isWinAInit = false;

  // Webview B: Range/9 (BTC/ETH)
  WebViewController? _mobileB;
  final _winB = win.WebviewController();
  bool _isWinBInit = false;

  Timer? _scrapeTimer;
  HyperData? _lastHyperData; // Accumulate data from both sources

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
    
    // Start loop after a delay to allow initialization
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
    } catch (e) {
      print('Error init $url: $e');
    }
  }

  void _startScrapingLoop() {
    _scrapeBoth();
    _scrapeTimer?.cancel();
    _scrapeTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      _scrapeBoth();
    });
  }

  Future<void> _scrapeBoth() async {
    // 1. Scrape Printer
    final printerResult = await _executeScrape(_winA, _mobileA, _printerJs);
    print("--- [DEBUG] 印鈔機原始數據 ---");
    print(printerResult);
    _parsePrinter(printerResult);

    // 2. Scrape Range
    final rangeResult = await _executeScrape(_winB, _mobileB, _rangeJs);
    print("--- [DEBUG] BTC/ETH 原始數據 ---");
    print(rangeResult);
    _parseRange(rangeResult);
    
    // 3. Notify UI
    if (_lastHyperData != null) {
      widget.onDataScraped(_lastHyperData!);
    }
  }

  Future<String?> _executeScrape(win.WebviewController? winCtrl, WebViewController? mobCtrl, String js) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        if (winCtrl == null) return null;
        await winCtrl.reload();
        await Future.delayed(const Duration(seconds: 5)); // Increased to 5s
        return await winCtrl.executeScript(js);
      } else {
        if (mobCtrl == null) return null;
        await mobCtrl.reload();
        await Future.delayed(const Duration(seconds: 5)); // Increased to 5s
        final res = await mobCtrl.runJavaScriptReturningResult(js);
        String s = res.toString();
        if (s.startsWith('"') || s.startsWith("'")) s = s.substring(1, s.length - 1);
        return s.replaceAll(r'\"', '"');
      }
    } catch (e) {
      print("Scrape Error: $e");
      return null;
    }
  }

  static const _printerJs = r"""
    (function() {
      const rows = document.querySelectorAll('tr');
      for (const row of rows) {
        const text = row.innerText;
        // Check for both Simplified and Traditional Chinese
        if (text.includes('超级印钞机') || text.includes('超级印鈔機') || text.includes('Super Money Printer')) {
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

  static const _rangeJs = r"""
    (function() {
      const rows = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
      if (rows.length === 0) return JSON.stringify({error: "No rows found with cg-style-g99dwx"});
      
      let data = { btc: null, eth: null, debug_all_text: "" };
      
      for (const row of rows) {
        const text = row.innerText;
        data.debug_all_text += text.substring(0, 50).replace(/\n/g, ' ') + " | ";
        
        let symbol = "";
        if (text.includes('BTC') && !text.includes('WBTC')) symbol = "BTC";
        else if (text.includes('ETH') && !text.includes('WETH')) symbol = "ETH";
        
        if (symbol && !data[symbol.toLowerCase()]) {
          // Robust regex: Match $ followed by numbers/dots and ending with unit
          const matches = text.match(/\$[\d,.]+[亿万]/g);
          
          if (matches && matches.length >= 2) {
            data[symbol.toLowerCase()] = {
              symbol: symbol,
              long: matches[0],
              short: matches[1],
              total: matches[2] || matches[1] || "0",
              match_count: matches.length
            };
          } else {
            data[symbol.toLowerCase()] = {
              symbol: symbol,
              error: "Regex failed",
              found_text: text.replace(/\n/g, ' ')
            };
          }
        }
      }
      return JSON.stringify(data);
    })();
  """;

  void _parsePrinter(String? raw) {
    if (raw == null || raw == "null") return;
    try {
      final d = jsonDecode(_cleanJson(raw));
      _lastHyperData = HyperData(
        timestamp: DateTime.now(),
        walletCount: _toInt(d['walletCount']),
        openPositionCount: _toInt(d['openPositionCount']),
        openPositionPct: d['openPositionPct'],
        profitCount: _toInt(d['profitCount']),
        lossCount: _toInt(d['lossCount']),
        longVolDisplay: d['longVol'],
        shortVolDisplay: d['shortVol'],
        netVolDisplay: d['netVol'],
        sentiment: d['sentiment'],
        longVolNum: _parseValue(d['longVol']),
        shortVolNum: _parseValue(d['shortVol']),
        netVolNum: _parseValue(d['netVol']),
        btc: _lastHyperData?.btc,
        eth: _lastHyperData?.eth,
      );
    } catch (e) { print("Printer Parse Error: \$e"); }
  }

  void _parseRange(String? raw) {
    if (raw == null || raw == "null" || _lastHyperData == null) return;
    try {
      final d = jsonDecode(_cleanJson(raw));
      final btc = d['btc'] != null ? _toCoinPos(d['btc']) : _lastHyperData?.btc;
      final eth = d['eth'] != null ? _toCoinPos(d['eth']) : _lastHyperData?.eth;
      
      _lastHyperData = HyperData(
        timestamp: _lastHyperData!.timestamp,
        walletCount: _lastHyperData!.walletCount,
        openPositionCount: _lastHyperData!.openPositionCount,
        openPositionPct: _lastHyperData!.openPositionPct,
        profitCount: _lastHyperData!.profitCount,
        lossCount: _lastHyperData!.lossCount,
        longVolDisplay: _lastHyperData!.longVolDisplay,
        shortVolDisplay: _lastHyperData!.shortVolDisplay,
        netVolDisplay: _lastHyperData!.netVolDisplay,
        sentiment: _lastHyperData!.sentiment,
        longVolNum: _lastHyperData!.longVolNum,
        shortVolNum: _lastHyperData!.shortVolNum,
        netVolNum: _lastHyperData!.netVolNum,
        btc: btc,
        eth: eth,
      );
    } catch (e) { print("Range Parse Error: \$e"); }
  }

  CoinPosition _toCoinPos(Map<String, dynamic> d) {
    return CoinPosition(
      symbol: d['symbol'],
      longVol: _parseValue(d['long']),
      shortVol: _parseValue(d['short']),
      totalVol: _parseValue(d['total']),
      longDisplay: d['long'],
      shortDisplay: d['short'],
      totalDisplay: d['total'],
    );
  }

  int _toInt(dynamic v) => int.tryParse(v.toString().replaceAll(',', '')) ?? 0;

  String _cleanJson(String s) {
    if (s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).replaceAll(r'\"', '"');
    }
    return s.replaceAll(r'\\', r'\');
  }

  double _parseValue(String raw) {
    try {
      String clean = raw.replaceAll(r'$', '').replaceAll(',', '').trim();
      double multiplier = 1.0;
      if (clean.contains('亿') || clean.contains('億')) { 
        multiplier = 100000000.0; 
        clean = clean.replaceAll('亿', '').replaceAll('億', ''); 
      }
      else if (clean.contains('万') || clean.contains('萬')) { 
        multiplier = 10000.0; 
        clean = clean.replaceAll('万', '').replaceAll('萬', ''); 
      }
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
