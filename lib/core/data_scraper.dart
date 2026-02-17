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
  bool _isFirstScrape = true;
  int _failCountA = 0;
  int _failCountB = 0;

  // Deduplication state
  String? _lastUploadedPrinter;
  String? _lastUploadedRange;
  DateTime _lastPrinterUploadTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRangeUploadTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initWebviews();
  }

  void _initWebviews() {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _initWindowsWebview(_winA, 'https://www.coinglass.com/zh/hl', (ok) => setState(() => _isWinAInit = ok));
      _initWindowsWebview(_winB, 'https://www.coinglass.com/zh/hl/range/9', (ok) => setState(() => _isWinBInit = ok));
      Future.delayed(const Duration(seconds: 5), () => _startScrapingLoop());
    } else {
      _mobileA = _createMobileController('https://www.coinglass.com/zh/hl');
      _mobileB = _createMobileController('https://www.coinglass.com/zh/hl/range/9');
      // Mobile SPA needs more time for initial page render + JS bundle execution
      Future.delayed(const Duration(seconds: 10), () => _startScrapingLoop());
    }
  }

  WebViewController _createMobileController(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) => debugPrint('[Scraper] Page loaded: $url'),
        onWebResourceError: (err) => debugPrint('[Scraper] Resource error: ${err.description}'),
      ))
      ..loadRequest(Uri.parse(url));
    return controller;
  }

  Future<void> _initWindowsWebview(win.WebviewController ctrl, String url, Function(bool) onInit) async {
    try {
      await ctrl.initialize();
      await ctrl.setBackgroundColor(Colors.transparent);
      await ctrl.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
      await ctrl.loadUrl(url);
      onInit(true);
    } catch (e) {
      debugPrint('Error initializing Windows Webview: $e');
    }
  }

  void _startScrapingLoop() {
    _doScrapes();
    _scrapeTimer?.cancel();
    // Check frequently (10s) for changes, but only upload on change or heartbeat
    _scrapeTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _doScrapes());
  }

  Future<void> _doScrapes() async {
    bool canScrapeA = (defaultTargetPlatform == TargetPlatform.windows) ? _isWinAInit : true;
    bool canScrapeB = (defaultTargetPlatform == TargetPlatform.windows) ? _isWinBInit : true;
    final now = DateTime.now();

    if (canScrapeA) {
      final printerResult = await _executeScrape(_winA, _mobileA, _printerJs);
      if (printerResult != null && printerResult != "null") {
        _failCountA = 0;

        // Deduplication Logic
        bool changed = (printerResult != _lastUploadedPrinter);
        bool heartbeat = now.difference(_lastPrinterUploadTime).inSeconds > 60;

        if (changed || heartbeat) {
           final data = _parsePrinterJson(printerResult);
           if (data != null) {
             debugPrint('[Scraper] ✅ Printer data upload (Change: $changed, Heartbeat: $heartbeat)');
             widget.onPrinterData(data);
             _lastUploadedPrinter = printerResult;
             _lastPrinterUploadTime = now;
           }
        }
      } else {
        _failCountA++;
        debugPrint('[Scraper] ❌ Printer scrape failed (#$_failCountA)');
      }
    }

    if (canScrapeB) {
      final rangeResult = await _executeScrape(_winB, _mobileB, _rangeJs);
      if (rangeResult != null && rangeResult != "null") {
        _failCountB = 0;

        // Deduplication Logic
        bool changed = (rangeResult != _lastUploadedRange);
        bool heartbeat = now.difference(_lastRangeUploadTime).inSeconds > 60;

        if (changed || heartbeat) {
          final data = _parseRangeJson(rangeResult);
          if (data != null) {
            debugPrint('[Scraper] ✅ Range data upload (Change: $changed, Heartbeat: $heartbeat)');
            widget.onRangeData(data);
            _lastUploadedRange = rangeResult;
            _lastRangeUploadTime = now;
          }
        }
      } else {
        _failCountB++;
        debugPrint('[Scraper] ❌ Range scrape failed (#$_failCountB)');
      }
    }
    _isFirstScrape = false;
  }

  Future<String?> _executeScrape(win.WebviewController? winCtrl, WebViewController? mobCtrl, String js) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        if (winCtrl == null) return null;
        await winCtrl.reload();
        await Future.delayed(const Duration(seconds: 2));
        return await winCtrl.executeScript(js);
      } else {
        if (mobCtrl == null) return null;

        // Mobile strategy: try JS first without reload (Coinglass SPA may auto-update)
        if (!_isFirstScrape) {
          try {
            final quickRes = await mobCtrl.runJavaScriptReturningResult(js);
            String q = _cleanMobileResult(quickRes);
            if (q != "null" && q.isNotEmpty && q.length > 5) {
              return q; // Page data was already fresh, no reload needed
            }
          } catch (_) {}

          // Quick scrape returned empty — reload page and retry with longer wait
          debugPrint('[Scraper] Quick scrape empty, reloading page...');
          await mobCtrl.reload();
          await Future.delayed(const Duration(seconds: 5));
        }

        final res = await mobCtrl.runJavaScriptReturningResult(js);
        return _cleanMobileResult(res);
      }
    } catch (e) {
      debugPrint('[Scraper] Error: $e');
      return null;
    }
  }

  String _cleanMobileResult(Object res) {
    String s = res.toString();
    if (s.startsWith('"') && s.endsWith('"')) s = s.substring(1, s.length - 1);
    return s.replaceAll(r'\"', '"');
  }

  static const _printerJs = r"""
    (function() {
      const getRow = (key, texts) => {
        let row = document.querySelector(`tr[data-row-key="${key}"]`);
        if (!row) {
          const rows = document.querySelectorAll('tr');
          for (const r of rows) {
            const t = r.innerText;
            if (texts.some(txt => t.includes(txt))) {
              row = r; break;
            }
          }
        }
        return row;
      };

      const parseRow = (row) => {
        if (!row) return null;
        const cells = row.querySelectorAll('td');
        if (cells.length < 8) return null;
        const volDivs = cells[4].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
        const plDivs = cells[7].querySelectorAll('div.cg-style-3a6fvj, div.cg-style-zuy5by');
        const sentimentBtn = row.querySelector('button.tag-but');
        return {
          walletCount: cells[2] ? cells[2].innerText.trim() : "0",
          longVol: volDivs[0] ? volDivs[0].innerText.trim() : "0",
          shortVol: volDivs[1] ? volDivs[1].innerText.trim() : "0",
          netVol: cells[5] ? cells[5].innerText.trim() : "0",
          profitCount: plDivs[0] ? plDivs[0].innerText.trim() : "0",
          lossCount: plDivs[1] ? plDivs[1].innerText.trim() : "0",
          sentiment: sentimentBtn ? sentimentBtn.innerText.trim() : ""
        };
      };

      const printerRow = getRow('Money_Printer', ['超级印钞', '超級印鈔']);
      const smartRow = getRow('Smart_Money', ['聪明钱', '聰明錢']);

      const printerData = parseRow(printerRow);
      const smartData = parseRow(smartRow);

      if (!printerData && !smartData) return null;

      return JSON.stringify({
        found: true,
        ...(printerData || {}),
        smart: smartData
      });
    })();
  """;

  static const _rangeJs = r"""
    (function() {
      // Range logic remains same, searching for BTC/ETH rows
      const allDivs = document.querySelectorAll('div[class*="cg-style-g99dwx"]');
      let data = { btc: null, eth: null };
      for (const row of allDivs) {
        const text = row.innerText;
        let symbol = "";
        if (text.includes('BTC') && !text.includes('WBTC')) symbol = "btc";
        else if (text.includes('ETH') && !text.includes('WETH')) symbol = "eth";

        if (symbol) {
          const amounts = row.querySelectorAll('div[class*="cg-style-3a6fvj"], div[class*="cg-style-zuy5by"], div.Number');
          if (amounts.length >= 2) {
             // Usually: Long, Short, ..., Total
             // Or sometimes: Long, Short, Net
             // We take first two as L/S, last as Total/Net
            data[symbol] = {
              symbol: symbol.toUpperCase(),
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
      final s = d['smart'] ?? {};
      return HyperData(
        timestamp: DateTime.now().toTaiwanTime(),
        walletCount: _toInt(d['walletCount']),
        profitCount: _toInt(d['profitCount']),
        lossCount: _toInt(d['lossCount']),
        sentiment: _toTC(d['sentiment']),
        longVolNum: _parseValue(d['longVol']),
        shortVolNum: _parseValue(d['shortVol']),
        netVolNum: _parseValue(d['netVol']),

        // Smart Money mapping
        smartWalletCount: _toInt(s['walletCount']),
        smartProfitCount: _toInt(s['profitCount']),
        smartLossCount: _toInt(s['lossCount']),
        smartSentiment: _toTC(s['sentiment']),
        smartLongVolNum: _parseValue(s['longVol']),
        smartShortVolNum: _parseValue(s['shortVol']),
        smartNetVolNum: _parseValue(s['netVol']),

        btc: _lastHyperData?.btc,
        eth: _lastHyperData?.eth,
      );
    } catch (e) { return null; }
  }

  HyperData? _parseRangeJson(String raw) {
    try {
      final d = jsonDecode(_cleanJson(raw));
      _lastHyperData = HyperData(
        timestamp: DateTime.now().toTaiwanTime(),
        walletCount: _lastHyperData?.walletCount ?? 0,
        profitCount: _lastHyperData?.profitCount ?? 0,
        lossCount: _lastHyperData?.lossCount ?? 0,
        sentiment: _lastHyperData?.sentiment ?? "",
        longVolNum: _lastHyperData?.longVolNum ?? 0,
        shortVolNum: _lastHyperData?.shortVolNum ?? 0,
        netVolNum: _lastHyperData?.netVolNum ?? 0,
        btc: d['btc'] != null ? _toCoinPos(d['btc']) : _lastHyperData?.btc,
        eth: d['eth'] != null ? _toCoinPos(d['eth']) : _lastHyperData?.eth,
      );
      return _lastHyperData;
    } catch (e) { return null; }
  }

  CoinPosition _toCoinPos(Map<String, dynamic> d) {
    final l = _parseValue(d['long']);
    final s = _parseValue(d['short']);
    final t = _parseValue(d['total']);
    return CoinPosition(
      symbol: d['symbol'], longVol: l, shortVol: s, totalVol: t, netVol: l - s,
    );
  }

  String _toTC(String s) => s.replaceAll('超级', '超級').replaceAll('印钞机', '印鈔機').replaceAll('亿', '億').replaceAll('万', '萬').replaceAll('涨', '漲').replaceAll('强', '強').replaceAll('势', '勢').replaceAll('态', '態');
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
    SizedBox(width: 1, height: 1, child: defaultTargetPlatform == TargetPlatform.windows
      ? (_isWinAInit ? win.Webview(_winA) : Container())
      : (_mobileA != null ? WebViewWidget(controller: _mobileA!) : Container())),
    SizedBox(width: 1, height: 1, child: defaultTargetPlatform == TargetPlatform.windows
      ? (_isWinBInit ? win.Webview(_winB) : Container())
      : (_mobileB != null ? WebViewWidget(controller: _mobileB!) : Container())),
  ]);

  @override
  void dispose() {
    _scrapeTimer?.cancel();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _winA.dispose();
      _winB.dispose();
    }
    super.dispose();
  }
}
