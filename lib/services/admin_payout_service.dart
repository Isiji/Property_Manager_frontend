// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AdminPayoutService {
  static Map<String, dynamic> _tryDecodeMap(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return {'detail': body};
  }

  static String _errMsg(http.Response res) {
    final m = _tryDecodeMap(res.body);
    final d = (m['detail'] ?? m['message'] ?? res.body).toString();
    return '${res.statusCode} $d';
  }

  static Future<List<Map<String, dynamic>>> listPayoutsForLandlord(int landlordId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/landlord/$landlordId');

    final res = await http.get(url, headers: {'Content-Type': 'application/json', ...headers});
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      return [];
    }
    throw Exception('Failed to load payouts: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> createPayout(Map<String, dynamic> payload) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }
    throw Exception('Failed to create payout: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> updatePayout(int payoutId, Map<String, dynamic> payload) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/$payoutId');

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }
    throw Exception('Failed to update payout: ${_errMsg(res)}');
  }

  static Future<void> deletePayout(int payoutId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/$payoutId');

    final res = await http.delete(url, headers: {'Content-Type': 'application/json', ...headers});
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete payout: ${_errMsg(res)}');
    }
  }
}
