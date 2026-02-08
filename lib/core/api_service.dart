import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'data_model.dart';

class ApiService {
  static const String baseUrl = 'https://hyper-monitor-worker.bennytsai0711.workers.dev';

  // [發報機專用]：分開上傳兩組數據
  Future<void> updatePrinter(HyperData data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/update-printer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'walletCount': data.walletCount,
          'profitCount': data.profitCount,
          'lossCount': data.lossCount,
          'longVolNum': data.longVolNum,
          'shortVolNum': data.shortVolNum,
          'netVolNum': data.netVolNum,
          'sentiment': data.sentiment,
          'longDisplay': data.longVolDisplay,
          'shortDisplay': data.shortVolDisplay,
          'netDisplay': data.netVolDisplay,
        }),
      );
    } catch (e) {
      debugPrint('Error updating printer: $e');
    }
  }

  Future<void> updateRange(HyperData data) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/update-range'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'btc': data.btc?.toJson(),
          'eth': data.eth?.toJson(),
        }),
      );
    } catch (e) {
      debugPrint('Error updating range: $e');
    }
  }

  // [接收機專用]
  Future<HyperData?> fetchLatest() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/latest'));
      if (res.statusCode == 200) {
        return HyperData.fromJson(jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint('Error fetching latest: $e');
    }
    return null;
  }

  Future<Map<String, List<HyperData>>> fetchHistory(String range) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/history?range=$range'));
      if (res.statusCode == 200) {
        final Map<String, dynamic> raw = jsonDecode(res.body);
        final List pRaw = raw['printer'] ?? [];
        final List bRaw = raw['btc'] ?? [];
        final List eRaw = raw['eth'] ?? [];

        return {
          'printer': pRaw.map((i) => HyperData.fromJson(i)).toList(),
          'btc': bRaw.map((i) => HyperData.fromJson({'timestamp': i['timestamp'], 'btc': i})).toList(),
          'eth': eRaw.map((i) => HyperData.fromJson({'timestamp': i['timestamp'], 'eth': i})).toList(),
        };
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    }
    return {'printer': [], 'btc': [], 'eth': []};
  }
}