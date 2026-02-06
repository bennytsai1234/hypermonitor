import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;
import 'data_model.dart';
import 'package:intl/intl.dart';

class CoinglassScraper extends StatefulWidget {
  final Function(HyperData) onDataScraped;

  const CoinglassScraper({Key? key, required this.onDataScraped}) : super(key: key);

  @override
  State<CoinglassScraper> createState() => _CoinglassScraperState();
}

class _CoinglassScraperState extends State<CoinglassScraper> {
  // Mobile WebViewController
  WebViewController? _mobileController;

  // Windows WebViewController
  final _windowsController = win.WebviewController();
  bool _isWindowsInitialized = false;

  Timer? _scrapeTimer;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _initWindowsWebview();
    } else {
      _initMobileWebview();
    }
  }

  void _initMobileWebview() {
    _mobileController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print('Page finished loading: $url');
            _startScrapingLoop();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.coinglass.com/zh/hl'));
  }

  Future<void> _initWindowsWebview() async {
    try {
      await _windowsController.initialize();
      await _windowsController.setBackgroundColor(Colors.transparent);
      await _windowsController.setPopupWindowPolicy(win.WebviewPopupWindowPolicy.deny);
      await _windowsController.loadUrl('https://www.coinglass.com/zh/hl');

      _windowsController.loadingState.listen((state) {
        if (state == win.LoadingState.navigationCompleted) {
            print('Windows Page loaded');
            _startScrapingLoop();
        }
      });

      if (mounted) setState(() {
        _isWindowsInitialized = true;
      });
    } catch (e) {
      print('Error initializing Windows webview: $e');
    }
  }

  void _startScrapingLoop() {
    // Scrape immediately then every 60 seconds
    _scrape();
    _scrapeTimer?.cancel();
    int scrapeCount = 0;
    // User requested reload every 5 seconds
    _scrapeTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      scrapeCount++;

      // Always reload to ensure fresh data
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await _windowsController.reload();
      } else {
        await _mobileController?.reload();
      }

      // Give it time to load the React app (3 seconds)
      Future.delayed(const Duration(seconds: 3), () {
        _scrape();
      });
    });
  }

  Future<void> _scrape() async {
    const jsScript = """
      (function() {
        try {
          const rows = document.querySelectorAll('tr');
          for (const row of rows) {
            if (row.innerText.includes('超级印钞机') || row.innerText.includes('Super Money Printer')) {
              return row.innerText;
            }
          }
          return null;
        } catch (e) {
          return 'Error: ' + e.toString();
        }
      })();
    """;

    try {
      String? result;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        result = await _windowsController.executeScript(jsScript);
      } else {
        final mobileResult = await _mobileController?.runJavaScriptReturningResult(jsScript);
        result = mobileResult.toString();
        // clean up quotes from mobile result
        if (result != null && (result.startsWith('"') || result.startsWith("'"))) {
           result = result.substring(1, result.length - 1);
        }
      }

      print("Scrape Result: $result");

      if (result != null && result != 'null' && !result.contains('Error:')) {
         _parseAndNotify(result);
      }
    } catch (e) {
      print("Scrape Execution Error: $e");
    }
  }

  void _parseAndNotify(String rawText) {
    // Raw text comes in as tab or newline separated usually depending on browser innerText implementation
    // formatting: "$100万 到 ∞\t超级印钞机\t579\t298 (51.47%)\t$5.21亿\t$14.14亿\t$19.36亿..."
    // We need to be robust. using regex or split.

    // Simple split by newline or tab
    final parts = rawText.split(RegExp(r'[\t\n]'));
    // Filter empty
    final cleaned = parts.where((p) => p.trim().isNotEmpty).toList();

    if (cleaned.length < 6) return;

    // Assuming order: Range, Name, Count, Open%, Long, Short, Net...
    // Let's look for known patterns.
    // Count is an integer.
    // Vols start with $.

    try {
      int? count;
      String long = "0";
      String short = "0";
      String net = "0";

      for (int i = 0; i < cleaned.length; i++) {
        final p = cleaned[i].trim();
        if (p == '超级印钞机') {
             // Index 2: count
             // Index 4: Long
             // Index 5: Short
             // Index 6: Net
             if (i+1 < cleaned.length) count = int.tryParse(cleaned[i+1].replaceAll(',', ''));
             if (i+3 < cleaned.length) long = cleaned[i+3];
             if (i+4 < cleaned.length) short = cleaned[i+4];
             if (i+5 < cleaned.length) net = cleaned[i+5];
             break;
        }
      }

      if (count != null) {
        final data = HyperData(
          timestamp: DateTime.now(),
          walletCount: count,
          longVolDisplay: long,
          shortVolDisplay: short,
          netVolDisplay: net,
          longVolNum: _parseValue(long),
          shortVolNum: _parseValue(short),
          netVolNum: _parseValue(net),
        );
        widget.onDataScraped(data);
      }
    } catch (e) {
      print("Parse Error: $e");
    }
  }

  double _parseValue(String raw) {
    // Expected formats: "$5.21亿", "$7497.65万", "$100"
    try {
      String clean = raw.replaceAll(r'$', '').replaceAll(',', '').trim();
      double multiplier = 1.0;

      if (clean.contains('亿')) {
        multiplier = 100000000.0;
        clean = clean.replaceAll('亿', '');
      } else if (clean.contains('万')) {
        multiplier = 10000.0;
        clean = clean.replaceAll('万', '');
      }

      return (double.tryParse(clean) ?? 0.0) * multiplier;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide the webview but keep it active
    return SizedBox(
      width: 1,
      height: 1,
      child: defaultTargetPlatform == TargetPlatform.windows
          ? (_isWindowsInitialized ? win.Webview(_windowsController) : Container())
          : WebViewWidget(controller: _mobileController!),
    );
  }

  @override
  void dispose() {
    _scrapeTimer?.cancel();
    _windowsController.dispose();
    super.dispose();
  }
}
