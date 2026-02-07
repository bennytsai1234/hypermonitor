import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'data_model.dart';

class CoinglassScraper extends StatefulWidget {
  final Function(HyperData) onDataScraped;

  const CoinglassScraper({super.key, required this.onDataScraped});

  @override
  State<CoinglassScraper> createState() => _CoinglassScraperState();
}

class _CoinglassScraperState extends State<CoinglassScraper> {
  late final WebViewController _mobileA;
  late final WebViewController _mobileB;
  
  Timer? _scrapeTimer;
  HyperData? _lastHyperData;

  @override
  void initState() {
    super.initState();
    _initWebviews();
  }

  void _initWebviews() {
    _mobileA = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://www.coinglass.com/zh/hl'));

    _mobileB = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://www.coinglass.com/zh/hl/range/9'));
    
    Future.delayed(const Duration(seconds: 10), () {
      _startScrapingLoop();
    });
  }

  void _startScrapingLoop() {
    _scrapeBoth();
    _scrapeTimer?.cancel();
    _scrapeTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      _scrapeBoth();
    });
  }

  Future<void> _scrapeBoth() async {
    final printerResult = await _executeScrape(_mobileA, _printerJs);
    _parsePrinter(printerResult);

    final rangeResult = await _executeScrape(_mobileB, _rangeJs);
    _parseRange(rangeResult);
    
    if (_lastHyperData != null) {
      widget.onDataScraped(_lastHyperData!);
    }
  }

  Future<String?> _executeScrape(WebViewController ctrl, String js) async {
    try {
      await ctrl.reload();
      await Future.delayed(const Duration(seconds: 5));
      final res = await ctrl.runJavaScriptReturningResult(js);
      String s = res.toString();
      if (s.startsWith('"') && s.endsWith('"')) {
        s = s.substring(1, s.length - 1);
      }
      return s.replaceAll(r'"', '"');
    } catch (e) {
      return null;
    }
  }

  static const _printerJs = r"""
    (function() {
      const rows = document.querySelectorAll('tr');
      for (const row of rows) {
        const text = row.innerText;
        if (text.includes('超级印钞机') || text.includes('超級印鈔機') || text.includes('Super Money Printer')) {
          const cells = row.querySelectorAll('td');
          if (cells.length < 8) continue;
          const volParts = cells[4].innerText.trim().split('
');
          const plParts = cells[6].innerText.trim().split('
');
          return JSON.stringify({
            found: true,
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
      return JSON.stringify({found: false});
    })();
  """;

  static const _rangeJs = r"""
    (function() {
      const rows = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
      if (rows.length === 0) return JSON.stringify({found: false, error: "No rows found"});
      
      let data = { found: true, btc: null, eth: null };
      for (const row of rows) {
        const text = row.innerText;
        let symbol = "";
        if (text.includes('BTC') && !text.includes('WBTC')) symbol = "BTC";
        else if (text.includes('ETH') && !text.includes('WETH')) symbol = "ETH";
        
        if (symbol && !data[symbol.toLowerCase()]) {
          const matches = text.match(/\$[\d,.]+[亿万B M]/g);
          if (matches && matches.length >= 2) {
            data[symbol.toLowerCase()] = {
              symbol: symbol,
              long: matches[0],
              short: matches[1],
              total: matches[2] || matches[1] || "0"
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
      final d = jsonDecode(raw);
      if (d['found'] != true) return;
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
    } catch (e) { }
  }

  void _parseRange(String? raw) {
    if (raw == null || raw == "null" || _lastHyperData == null) return;
    try {
      final d = jsonDecode(raw);
      if (d['found'] != true) return;
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
      longDisplay: d['long'], 
      shortDisplay: d['short'], 
      totalDisplay: d['total'],
      netDisplay: netStr,
    );
  }

  int _toInt(dynamic v) => int.tryParse(v.toString().replaceAll(',', '')) ?? 0;

  double _parseValue(String raw) {
    try {
      String clean = raw.replaceAll(RegExp(r'[\$¥,]'), '').trim();
      double multiplier = 1.0;
      if (clean.contains('亿') || clean.contains('億') || clean.contains('B')) { 
        multiplier = 100000000.0; 
        clean = clean.replaceAll(RegExp(r'[亿億B]'), ''); 
      }
      else if (clean.contains('万') || clean.contains('萬') || clean.contains('M')) { 
        multiplier = 10000.0; 
        clean = clean.replaceAll(RegExp(r'[万萬M]'), ''); 
      }
      return (double.tryParse(clean) ?? 0.0) * multiplier;
    } catch (e) { return 0.0; }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(width: 1, height: 1, child: WebViewWidget(controller: _mobileA)),
        SizedBox(width: 1, height: 1, child: WebViewWidget(controller: _mobileB)),
      ],
    );
  }

  @override
  void dispose() {
    _scrapeTimer?.cancel();
    super.dispose();
  }
}
