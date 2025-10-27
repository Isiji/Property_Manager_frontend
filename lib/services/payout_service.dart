// lib/services/payout_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class PayoutService {
  static Future<List<dynamic>> listForLandlord(int landlordId) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/landlord/$landlordId');
    print('[PayoutService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    });
    print('[PayoutService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load payouts: ${res.body}');
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> payload) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/');
    print('[PayoutService] POST $url payload=$payload');
    final res = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          ...await TokenManager.authHeaders(),
        },
        body: jsonEncode(payload));
    print('[PayoutService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create payout: ${res.body}');
  }

  static Future<Map<String, dynamic>> update(int payoutId, Map<String, dynamic> payload) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/$payoutId');
    print('[PayoutService] PUT $url payload=$payload');
    final res = await http.put(url,
        headers: {
          'Content-Type': 'application/json',
          ...await TokenManager.authHeaders(),
        },
        body: jsonEncode(payload));
    print('[PayoutService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update payout: ${res.body}');
  }

  static Future<void> deletePayout(int payoutId) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payouts/$payoutId');
    print('[PayoutService] DELETE $url');
    final res = await http.delete(url, headers: {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    });
    print('[PayoutService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Failed to delete payout: ${res.body}');
    }
  }
}
