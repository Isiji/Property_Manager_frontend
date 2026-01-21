// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class PaymentService {
  // -----------------------------
  // Helpers
  // -----------------------------
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

  static Map<String, dynamic> _decodeMapOrEmpty(http.Response res) {
    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }
    throw Exception(_errMsg(res));
  }

  // -----------------------------
  // M-Pesa STK Push (Tenant)
  // -----------------------------
  static Future<Map<String, dynamic>> initiateMpesa({
    required int leaseId,
    required num amount,
    String? phone,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/mpesa/initiate');

    final payload = {
      'lease_id': leaseId,
      'amount': amount.toDouble(),
      'phone': phone,
    }..removeWhere((k, v) => v == null);

    print('[PaymentService] POST $url');
    print('[PaymentService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    return _decodeMapOrEmpty(res);
  }

  // -----------------------------
  // Reports / Payment status
  // -----------------------------
  static Future<Map<String, dynamic>> getStatusByProperty({
    required int propertyId,
    required String period,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/reports/property/$propertyId/status?period=$period');

    print('[PaymentService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    return _decodeMapOrEmpty(res);
  }

  // -----------------------------
  // Record Cash / Manual Payment
  // -----------------------------
  /// ✅ Now matches your UI calls:
  /// recordPayment(... period: ..., paidDate: ...)
  static Future<Map<String, dynamic>> recordPayment({
    required int leaseId,
    required num amount,
    String method = 'cash',
    String? reference,
    String? notes,

    // your UI might call either of these:
    String? paidDate,  // ✅ NEW (matches landlord_property_units.dart)
    String? paidAtIso, // still supported

    String? period,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/record');

    // Prefer paidDate if provided, else paidAtIso
    final payload = {
      'lease_id': leaseId,
      'amount': amount.toDouble(),
      'method': method,
      'reference': reference,
      'notes': notes,
      'paid_date': paidDate, // ✅ if backend expects date-only
      'paid_at': paidDate == null ? paidAtIso : null, // avoid sending both
      'period': period,
    }..removeWhere((k, v) => v == null);

    print('[PaymentService] POST $url');
    print('[PaymentService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    return _decodeMapOrEmpty(res);
  }

  // -----------------------------
  // Reminders
  // -----------------------------
  static Future<void> sendReminder({
    required int leaseId,
    required String message,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/reminder');

    final payload = {
      'lease_id': leaseId,
      'message': message,
    };

    print('[PaymentService] POST $url');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode != 200 && res.statusCode != 201 && res.statusCode != 204) {
      throw Exception('Failed to send reminder: ${_errMsg(res)}');
    }
  }

  static Future<void> sendRemindersBulk({
    required int propertyId,
    required String message,
    String? period,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/reminders/bulk');

    final payload = {
      'property_id': propertyId,
      'message': message,
      'period': period,
    }..removeWhere((k, v) => v == null);

    print('[PaymentService] POST $url');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode != 200 && res.statusCode != 201 && res.statusCode != 204) {
      throw Exception('Failed to send bulk reminders: ${_errMsg(res)}');
    }
  }

  // -----------------------------
  // Receipt PDF
  // -----------------------------
  static Future<Uint8List> downloadReceiptPdf(int id) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/receipt/$id/pdf');

    print('[PaymentService] GET $url');
    final res = await http.get(url, headers: {
      ...headers,
    });

    print('[PaymentService] ← ${res.statusCode}');
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }
    throw Exception('Failed to download receipt PDF: ${_errMsg(res)}');
  }
}
