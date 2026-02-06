import 'dart:async';
import 'dart:convert';
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
    // Scrape immediately
    _scrape();
    _scrapeTimer?.cancel();

    // Poll every 10 seconds per user request
    _scrapeTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // Reload logic
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // Windows needs explicit reload to refresh data on SPA
        await _windowsController.reload();
      } else {
        await _mobileController?.reload();
      }

      // Check shortly after reload (give 2s for React to render)
      // This is much faster than the previous 10s hard wait
      Future.delayed(const Duration(seconds: 2), () {
        _scrape();
      });
    });
  }

  Future<void> _scrape() async {
    const jsScript = """
      (function() {
        try {
          const rows = document.querySelectorAll('tr');
          let debugRows = [];

          for (const row of rows) {
            const text = row.innerText;
            // Collect first 5 rows for debug if we fail
            if (debugRows.length < 5) debugRows.push(text.substring(0, 100).replace(/\\n/g, ' '));

            // Find the Super Money Printer row
            if (text.includes('超级印钞机') || text.includes('Super Money Printer')) {
               const cells = row.querySelectorAll('td');
               if (cells.length < 5) return JSON.stringify({error: "Found row but cells < 5"});

               // 1. Wallet Count (Index 2)
               let wallet = cells[2].innerText.trim();

               // 2. Long & Short Volume (Index 4 - Merged with newline)
               // Log confirmed: "\$5.65亿\\n\$14.43亿"
               // Note: Sometimes columns shift. We should ideally use headers but let's stick to this for now.
               let longVol = "0";
               let shortVol = "0";

               // Try to match the cell structure more dynamically if possible, but index 4 is our best guess from previous logs.
               // Let's also check if cells[4] has the expected currency format.
               const volCell = cells[4].innerText.trim();
               const volParts = volCell.split('\\n');

               if (volParts.length > 0) longVol = volParts[0].trim();
               if (volParts.length > 1) shortVol = volParts[1].trim();

               // 3. Net Volume (Index 5)
               let netVol = cells[5].innerText.trim();

               // 4. Sentiment (Usually 2nd to last, or find by text content if available)
               let sentiment = "Unknown";
               if (cells.length >= 2) {
                 sentiment = cells[cells.length - 2].innerText.trim();
                 if (!sentiment) sentiment = cells[cells.length - 1].innerText.trim();
               }

               return JSON.stringify({
                 found: true,
                 walletCount: wallet,
                 longVol: longVol,
                 shortVol: shortVol,
                 netVol: netVol,
                 sentiment: sentiment
               });
            }
          }

          // Return debug info if not found
          return JSON.stringify({
             found: false,
             message: "Row not found",
             totalRows: rows.length,
             sampleRows: debugRows
          });
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
        if (result != null && (result.startsWith('"') || result.startsWith("'"))) {
           result = result.substring(1, result.length - 1);
           result = result.replaceAll(r'\"', '"');
        }
      }

      print("Scrape Result: $result");

      if (result != null && result != 'null' && !result.contains('error')) {
         _parseAndNotify(result!.replaceAll(r'\\', r'\')); // Unescape slashes for jsonDecode
      }
    } catch (e) {
      print("Scrape Execution Error: $e");
    }
  }


  void _parseAndNotify(String rawJson) {
     try {
       // Clean up the JSON string for the Dart parser
       // Sometimes windows webview returns double escaped strings
       String cleanJson = rawJson;
       if (cleanJson.startsWith('"') && cleanJson.endsWith('"')) {
          cleanJson = cleanJson.substring(1, cleanJson.length - 1).replaceAll(r'\"', '"');
       }

       final Map<String, dynamic> data = jsonDecode(cleanJson);

       if (data['found'] == true) {
           final wCountStr = data['walletCount']?.toString() ?? "";
           final longStr = data['longVol']?.toString() ?? "0";
           final shortStr = data['shortVol']?.toString() ?? "0";
           final netStr = data['netVol']?.toString() ?? "0";
           final sentimentStr = data['sentiment']?.toString() ?? "Unknown";

           if (wCountStr.isNotEmpty) {
               final count = int.tryParse(wCountStr.replaceAll(',', '')) ?? 0;

               final hyperData = HyperData(
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
               widget.onDataScraped(hyperData);
           }
       } else {
         // Log debug info
         print("Scraper failed to find row. Debug info: ${data['sampleRows']}");
       }

     } catch (e) {
       print("JSON Parse Error: $e \nRaw: $rawJson");
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
