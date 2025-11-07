// lib/services/payment_service.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:typed_data';
// For web download
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/events/app_events.dart';

class PaymentService {
  static Map<String, String> _json(Map<String, String> h) => {
        'Content-Type': 'application/json',
        ...h,
      };

  /// GET /reports/property/{propertyId}/status?period=YYYY-MM
  static Future<Map<String, dynamic>> getStatusByProperty({
    required int propertyId,
    required String period,
  }) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/reports/property/$propertyId/status')
        .replace(queryParameters: {'period': period});
    print('[PaymentService] GET $url');
    final r = await http.get(url, headers: _json(h));
    print('[PaymentService] ← ${r.statusCode}');
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Status failed: ${r.statusCode} ${r.body}');
  }

  /// POST /payments/record (manual cash entry)
  static Future<Map<String, dynamic>> recordPayment({
    required int leaseId,
    required String period, // YYYY-MM
    required num amount,
    required String paidDate, // YYYY-MM-DD
  }) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/record');
    final body = {
      'lease_id': leaseId,
      'period': period,
      'amount': amount,
      'paid_date': paidDate,
    };
    print('[PaymentService] POST $url body=$body');
    final r = await http.post(url, headers: _json(h), body: jsonEncode(body));
    print('[PaymentService] ← ${r.statusCode} ${r.body}');
    if (r.statusCode == 200 || r.statusCode == 201) {
      final b = jsonDecode(r.body);
      // Manual record also counts as activity worth a refresh.
      AppEvents.I.paymentActivity.add(null);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Record payment failed: ${r.statusCode} ${r.body}');
  }

  /// POST /payments/remind
  static Future<Map<String, dynamic>> sendReminder({required int leaseId}) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/remind');
    final body = {'lease_id': leaseId};
    print('[PaymentService] POST $url body=$body');
    final r = await http.post(url, headers: _json(h), body: jsonEncode(body));
    print('[PaymentService] ← ${r.statusCode} ${r.body}');
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      // Not strictly needed, but you can refresh after reminders too.
      AppEvents.I.paymentActivity.add(null);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Reminder failed: ${r.statusCode} ${r.body}');
  }

  /// POST /payments/mpesa/initiate
  static Future<Map<String, dynamic>> initiateMpesa({
    required int leaseId,
    required num amount,
    String? phone,
  }) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/payments/mpesa/initiate');
    final body = {
      'lease_id': leaseId,
      'amount': amount,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };
    print('[PaymentService] POST $url body=$body');
    final r = await http.post(url, headers: _json(h), body: jsonEncode(body));
    print('[PaymentService] ← ${r.statusCode} ${r.body}');
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      // 🔔 Fire-and-forget event so landlord screen does a single refresh.
      AppEvents.I.paymentActivity.add(null);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('MPesa initiation failed: ${r.statusCode} ${r.body}');
  }

  // ---------- PDF RECEIPT HELPERS ----------

  /// Direct URL for a PDF receipt. Requires Bearer auth header.
  static String receiptUrl(int paymentId) =>
      '${AppConfig.apiBaseUrl}/payments/mpesa/receipt/$paymentId.pdf';

  /// Fetches the PDF and triggers a browser download (Flutter web).
  static Future<void> downloadReceiptPdf(int paymentId) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse(receiptUrl(paymentId));
    final r = await http.get(url, headers: h);
    if (r.statusCode == 200) {
      final bytes = Uint8List.fromList(r.bodyBytes);
      final blob = html.Blob([bytes], 'application/pdf');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: blobUrl)
        ..download = 'receipt_$paymentId.pdf'
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
      return;
    }
    throw Exception('Failed to download receipt: ${r.statusCode} ${r.body}');
  }
}
