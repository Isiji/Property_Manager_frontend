// payment_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class PaymentService {
  static Map<String, dynamic> _tryDecodeMap(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return {'detail': body};
  }

  static List<dynamic> _tryDecodeList(String body) {
    try {
      final v = jsonDecode(body);
      if (v is List) return v;
    } catch (_) {}
    return <dynamic>[];
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

  static List<String> _normalizePeriods({
    String? period,
    List<String>? periods,
  }) {
    final out = <String>[];

    if (periods != null) {
      for (final p in periods) {
        final v = p.trim();
        if (v.isNotEmpty) out.add(v);
      }
    }

    if (out.isEmpty && period != null && period.trim().isNotEmpty) {
      out.add(period.trim());
    }

    final seen = <String>{};
    final ordered = <String>[];

    for (final p in out) {
      if (!seen.contains(p)) {
        seen.add(p);
        ordered.add(p);
      }
    }

    ordered.sort();
    return ordered;
  }

  static Future<Map<String, String>> _headers({
    bool includeJsonContentType = true,
  }) async {
    final auth = await TokenManager.authHeaders();
    return {
      if (includeJsonContentType) 'Content-Type': 'application/json',
      ...auth,
    };
  }

  // -----------------------------
  // M-Pesa STK Push (Tenant)
  // -----------------------------
  static Future<Map<String, dynamic>> initiateMpesa({
    required int leaseId,
    required num amount,
    String? phone,
    String? period,
    List<String>? periods,
    String? notes,
  }) async {
    final headers = await _headers();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/mpesa/initiate');

    final normalizedPeriods = _normalizePeriods(period: period, periods: periods);

    final payload = <String, dynamic>{
      'lease_id': leaseId,
      'amount': amount.toDouble(),
      'phone': phone,
      'notes': notes,
      if (normalizedPeriods.isNotEmpty) 'periods': normalizedPeriods,
    }..removeWhere((k, v) => v == null);

    print('[PaymentService] POST $url');
    print('[PaymentService] headers: $headers');
    print('[PaymentService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    return _decodeMapOrEmpty(res);
  }

  // -----------------------------
  // Optional: check a payment by id
  // -----------------------------
  static Future<Map<String, dynamic>> getPaymentReceiptJson(int paymentId) async {
    final headers = await _headers();
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/payments/receipt/$paymentId',
    );

    print('[PaymentService] GET $url');
    final res = await http.get(url, headers: headers);

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    return _decodeMapOrEmpty(res);
  }

  // -----------------------------
  // Optional: get property payment status report
  // -----------------------------
  static Future<Map<String, dynamic>> getStatusByProperty({
    required int propertyId,
    required String period,
  }) async {
    final headers = await _headers();
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/reports/property/$propertyId/status?period=$period',
    );

    print('[PaymentService] GET $url');
    final res = await http.get(url, headers: headers);

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    return _decodeMapOrEmpty(res);
  }

  // -----------------------------
  // Optional: get payments by lease if backend supports it
  // -----------------------------
  static Future<List<dynamic>> listPaymentsByLease(int leaseId) async {
    final headers = await _headers();
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/payments/lease/$leaseId',
    );

    print('[PaymentService] GET $url');
    final res = await http.get(url, headers: headers);

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return _tryDecodeList(res.body);
    }
    throw Exception(_errMsg(res));
  }

  // -----------------------------
  // Record Cash / Manual Payment
  // -----------------------------
  static Future<Map<String, dynamic>> recordPayment({
    required int leaseId,
    required num amount,
    String method = 'cash',
    String? reference,
    String? notes,
    String? paidDate,
    String? paidAtIso,
    String? period,
    List<String>? periods,
  }) async {
    final headers = await _headers();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/record');

    final normalizedPeriods = _normalizePeriods(period: period, periods: periods);

    final payload = <String, dynamic>{
      'lease_id': leaseId,
      'amount': amount.toDouble(),
      'method': method,
      'reference': reference,
      'notes': notes,
      'paid_date': paidDate,
      'paid_at': paidDate == null ? paidAtIso : null,
      if (normalizedPeriods.isNotEmpty) 'periods': normalizedPeriods,
    }..removeWhere((k, v) => v == null);

    print('[PaymentService] POST $url');
    print('[PaymentService] headers: $headers');
    print('[PaymentService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: headers,
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
    final headers = await _headers();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/reminder');

    final payload = {
      'lease_id': leaseId,
      'message': message,
    };

    print('[PaymentService] POST $url');
    print('[PaymentService] headers: $headers');
    print('[PaymentService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode != 200 &&
        res.statusCode != 201 &&
        res.statusCode != 204) {
      throw Exception('Failed to send reminder: ${_errMsg(res)}');
    }
  }

  static Future<void> sendRemindersBulk({
    required int propertyId,
    required String message,
    String? period,
  }) async {
    final headers = await _headers();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/reminders/bulk');

    final payload = {
      'property_id': propertyId,
      'message': message,
      'period': period,
    }..removeWhere((k, v) => v == null);

    print('[PaymentService] POST $url');
    print('[PaymentService] headers: $headers');
    print('[PaymentService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    print('[PaymentService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode != 200 &&
        res.statusCode != 201 &&
        res.statusCode != 204) {
      throw Exception('Failed to send bulk reminders: ${_errMsg(res)}');
    }
  }

  // -----------------------------
  // Receipt PDF
  // -----------------------------
  static Future<Uint8List> downloadReceiptPdf(int paymentId) async {
    final headers = await _headers(includeJsonContentType: false);
    final url = Uri.parse(
      '${AppConfig.apiBaseUrl}/payments/receipt/$paymentId/pdf',
    );

    print('[PaymentService] GET $url');
    print('[PaymentService] headers: $headers');

    final res = await http.get(url, headers: headers);

    print('[PaymentService] ← ${res.statusCode}');
    if (res.statusCode == 200) {
      return res.bodyBytes;
    }

    try {
      print('[PaymentService] body: ${res.body}');
    } catch (_) {}

    throw Exception('Failed to download receipt PDF: ${_errMsg(res)}');
  }

  // -----------------------------
  // Lease PDF
  // -----------------------------
  static Future<Uint8List> downloadLeasePdf(int leaseId) async {
    final headers = await _headers(includeJsonContentType: false);

    final candidates = <Uri>[
      Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId/pdf'),
      Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId.pdf'),
    ];

    Exception? lastError;

    for (final url in candidates) {
      try {
        print('[PaymentService] GET $url');
        print('[PaymentService] headers: $headers');

        final res = await http.get(url, headers: headers);

        print('[PaymentService] ← ${res.statusCode}');
        if (res.statusCode == 200) {
          return res.bodyBytes;
        }

        try {
          print('[PaymentService] body: ${res.body}');
        } catch (_) {}

        lastError = Exception(
          'Failed to download lease PDF: ${_errMsg(res)}',
        );
      } catch (e) {
        lastError = Exception('Failed to download lease PDF: $e');
      }
    }

    throw lastError ?? Exception('Failed to download lease PDF');
  }
}