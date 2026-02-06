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

               // Dump all cells for debugging
               let cellDump = [];
               for (let i = 0; i < cells.length; i++) {
                 cellDump.push({idx: i, text: cells[i].innerText.trim().replace(/\\n/g, '|')});
               }

               // Confirmed Coinglass table structure from debug:
               // cells[0]: Filter range ($100万 到 ∞)
               // cells[1]: Name (超级印钞机)
               // cells[2]: Wallet count (578)
               // cells[3]: Open position count with percentage (e.g. "294 (50.87%)")
               // cells[4]: Long/Short Volume (e.g. "$5.74亿|$14.06亿")
               // cells[5]: Net Volume ($19.80亿)
               // cells[6]: Profit/Loss count (e.g. "225|70")
               // cells[7]: Sentiment (看跌)

               let wallet = cells[2].innerText.trim();

               // Open Position Count (Index 3)
               // Format: "294 (50.87%)" or just "294"
               let openPositionCount = "0";
               let openPositionPct = "";
               const posCell = cells[3].innerText.trim();
               // Extract number and percentage separately
               const pctMatch = posCell.match(/\\((\\d+\\.?\\d*%)\\)/);
               if (pctMatch) {
                 openPositionPct = pctMatch[1];
               }
               openPositionCount = posCell.replace(/\\(.*?\\)/, '').trim();

               // Long/Short Volume (Index 4)
               let longVol = "0";
               let shortVol = "0";
               const volCell = cells[4].innerText.trim();
               const volParts = volCell.split('\\n');
               if (volParts.length > 0) longVol = volParts[0].trim();
               if (volParts.length > 1) shortVol = volParts[1].trim();

               // Net Volume (Index 5)
               let netVol = cells[5].innerText.trim();

               // Profit/Loss Count (Index 6)
               let profitCount = "0";
               let lossCount = "0";
               if (cells.length > 6) {
                 const plCell = cells[6].innerText.trim();
                 const plParts = plCell.split('\\n');
                 if (plParts.length > 0) profitCount = plParts[0].trim();
                 if (plParts.length > 1) lossCount = plParts[1].trim();
               }

               // Sentiment (Index 7)
               let sentiment = "Unknown";
               if (cells.length > 7) {
                 sentiment = cells[7].innerText.trim();
               }

               return JSON.stringify({
                 found: true,
                 walletCount: wallet,
                 openPositionCount: openPositionCount,
                 openPositionPct: openPositionPct,
                 longVol: longVol,
                 shortVol: shortVol,
                 netVol: netVol,
                 profitCount: profitCount,
                 lossCount: lossCount,
                 sentiment: sentiment,
                 debug_cells: cellDump
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

      // Debug: Print full cells if available
      if (result != null && result.contains('debug_cells')) {
        try {
          String toParse = result;
          if (toParse.startsWith('"') && toParse.endsWith('"')) {
            toParse = toParse.substring(1, toParse.length - 1).replaceAll(r'\"', '"');
          }
          final debugData = jsonDecode(toParse);
          final cells = debugData['debug_cells'] as List;
          print("=== DEBUG CELLS (${cells.length} total) ===");
          for (var cell in cells) {
            print("  [${cell['idx']}] ${cell['text']}");
          }
          print("=== END DEBUG ===");
        } catch (e) {
          print("Debug parse error: $e");
        }
      }

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
           final openPosCountStr = data['openPositionCount']?.toString() ?? "0";
           final openPosPctStr = data['openPositionPct']?.toString() ?? "";
           final profitCountStr = data['profitCount']?.toString() ?? "0";
           final lossCountStr = data['lossCount']?.toString() ?? "0";
           final longStr = data['longVol']?.toString() ?? "0";
           final shortStr = data['shortVol']?.toString() ?? "0";
           final netStr = data['netVol']?.toString() ?? "0";
           final sentimentStr = data['sentiment']?.toString() ?? "Unknown";

           if (wCountStr.isNotEmpty) {
               final count = int.tryParse(wCountStr.replaceAll(',', '')) ?? 0;
               final openPosCount = int.tryParse(openPosCountStr.replaceAll(',', '')) ?? 0;
               final profitCount = int.tryParse(profitCountStr.replaceAll(',', '')) ?? 0;
               final lossCount = int.tryParse(lossCountStr.replaceAll(',', '')) ?? 0;

               final hyperData = HyperData(
                  timestamp: DateTime.now(),
                  walletCount: count,
                  openPositionCount: openPosCount,
                  openPositionPct: openPosPctStr,
                  profitCount: profitCount,
                  lossCount: lossCount,
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
