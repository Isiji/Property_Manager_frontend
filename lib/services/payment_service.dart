// lib/services/payment_service.dart
// Fetch monthly rent status & record payments / reminders.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class PaymentService {
  static Future<Map<String, dynamic>> getStatusByProperty({
    required int propertyId,
    required String period, // YYYY-MM
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    };
    final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/payments/status/by-property?property_id=$propertyId&period=$period');

    final res = await http.get(url, headers: headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load rent status: ${res.statusCode}\n${res.body}');
  }

  static Future<void> recordPayment({
    required int leaseId,
    required String period, // YYYY-MM
    required num amount,
    required String paidDate, // YYYY-MM-DD
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    };
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/record');
    final payload = {
      'lease_id': leaseId,
      'period': period,
      'amount': amount,
      'paid_date': paidDate,
    };
    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to record payment: ${res.statusCode}\n${res.body}');
    }
  }

  static Future<void> sendReminder({required int leaseId}) async {
    final headers = {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    };
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/remind/$leaseId');
    final res = await http.post(url, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Failed to send reminder: ${res.statusCode}\n${res.body}');
    }
  }
}
