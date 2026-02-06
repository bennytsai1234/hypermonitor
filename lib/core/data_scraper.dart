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
    // Scrape immediately then every 15 seconds (relaxed to allow load)
    _scrape();
    _scrapeTimer?.cancel();
    int scrapeCount = 0;

    _scrapeTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      scrapeCount++;

      // Always reload to ensure fresh data
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await _windowsController.reload();
      } else {
        await _mobileController?.reload();
      }

      // Give it time to load the React app (10 seconds)
      Future.delayed(const Duration(seconds: 10), () {
        _scrape();
      });
    });
  }

  Future<void> _scrape() async {
    const jsScript = """
      (function() {
        try {
          const rows = document.querySelectorAll('tr');
          let found = false;
          for (const row of rows) {
            if (row.innerText.includes('超级印钞机') || row.innerText.includes('Super Money Printer')) {
               const cells = row.querySelectorAll('td');
               // Defensive check
               if (cells.length < 6) return JSON.stringify({error: "Found row but cells < 6"});

               // Observed Layout matching fixes

               let sentiment = "Unknown";
               if (cells.length > 0) {
                 sentiment = cells[cells.length - 1].innerText.trim();
               }

               return JSON.stringify({
                 walletCount: cells[2].innerText.trim(),
                 longShortVol: cells[4].innerText.trim(),
                 netVol: cells[5].innerText.trim(),
                 sentiment: sentiment
               });
            }
          }
          return JSON.stringify({debug: "Row not found", title: document.title, rowCount: rows.length});
        } catch (e) {
          return JSON.stringify({error: e.toString()});
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
           // Mobile sometimes returns JSON escaped doubly
           result = result.replaceAll(r'\"', '"');
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

  void _parseAndNotify(String rawJson) {
     try {
       // Manual simple JSON parsing to avoid heavy imports if possible,
       // but since we are in Flutter, let's use dart:convert if we imported it?
       // We didn't import dart:convert. Let's add it or do simple regex.
       // Actually, adding import 'dart:convert'; is cleaner.
       // For now, let's assume we can add the import to the top of the file in a separate edit
       // or just do string manipulation if it's simple.
       // But wait, I can modify the import in this same file using multi_replace or just assume I will do it.
       // Let's use regex for safety without changing imports yet, or better,
       // I'll assume valid JSON structure: {"key":"value", ...}

       // Let's replace the whole file content helper to include dart:convert or just use string split if I want to be lazy.
       // No, I should be professional. I will include 'dart:convert' in a separate edit or use regex.
       // Given the constraints, I'll use a regex "parser" for this simple flat object to save an import cycle if I can't edit top.
       // Structure: {"key":"value", ...}

       String val(String key) {
         final match = RegExp('"$key":\\s*"([^"]+)"').firstMatch(rawJson);
         return match?.group(1) ?? ""; // This simple regex might fail on newlines inside value if not strictly escaped
       }

       // Robust simple JSON unescape for values that might contain \n
       String extract(String key) {
           final start = rawJson.indexOf('"$key":');
           if (start == -1) return "";
           final valStart = rawJson.indexOf('"', start + key.length + 3);
           if (valStart == -1) return "";

           // Find end quote, avoiding escaped quotes (simple check)
           int valEnd = valStart + 1;
           while (valEnd < rawJson.length) {
             if (rawJson[valEnd] == '"' && rawJson[valEnd-1] != '\\') {
               break;
             }
             valEnd++;
           }
           if (valEnd >= rawJson.length) return "";

           String rawVal = rawJson.substring(valStart + 1, valEnd);
           // Unescape basic json chars
           return rawVal.replaceAll(r'\n', '\n').replaceAll(r'\"', '"').replaceAll(r'\\', '\\');
       }

       final wCountStr = extract("walletCount");
       final longShortStr = extract("longShortVol");
       final netStr = extract("netVol");
       final sentimentStr = extract("sentiment").trim();

       if (wCountStr.isNotEmpty) {
           final count = int.tryParse(wCountStr.replaceAll(',', '')) ?? 0;

           // Split Long/Short
           // Expected: "$5.32亿\n$14.39亿"
           // Or sometimes tab separated?
           String longStr = "0";
           String shortStr = "0";

           final vols = longShortStr.split(RegExp(r'[\n\t]'));
           if (vols.isNotEmpty) longStr = vols[0].trim();
           if (vols.length > 1) shortStr = vols[1].trim();

           final data = HyperData(
              timestamp: DateTime.now(),
              walletCount: count,
              longVolDisplay: longStr,
              shortVolDisplay: shortStr,
              netVolDisplay: netStr,
              sentiment: sentimentStr,
              longVolNum: _parseValue(longStr),
              shortVolNum: _parseValue(shortStr),
              netVolNum: _parseValue(netStr),
           );
           widget.onDataScraped(data);
       }

     } catch (e) {
       print("JSON Parse Error: $e");
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
