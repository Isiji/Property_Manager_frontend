// lib/services/payment_service.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
import 'package:property_manager_frontend/events/app_events.dart';
// For web download
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PaymentService {
  static Map<String, String> _json(Map<String, String> h) => {
        'Content-Type': 'application/json',
        ...h,
      };

  static Future<Map<String, String>> _auth() => TokenManager.authHeaders();

  /// GET /reports/property/{propertyId}/status?period=YYYY-MM
  static Future<Map<String, dynamic>> getStatusByProperty({
    required int propertyId,
    required String period,
  }) async {
    final h = await _auth();
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
    final h = await _auth();
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
      AppEvents.I.paymentActivity.add(null);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Record payment failed: ${r.statusCode} ${r.body}');
  }

  /// POST /payments/remind  (single reminder)
  /// Optional message for SMS/WhatsApp + in-app notification.
  static Future<Map<String, dynamic>> sendReminder({
    required int leaseId,
    String? message,
  }) async {
    final h = await _auth();
    final u1 = Uri.parse('${AppConfig.apiBaseUrl}/payments/remind');
    final u2 = Uri.parse('${AppConfig.apiBaseUrl}/payments/remind/'); // tolerant fallback
    final body = {'lease_id': leaseId, if (message != null && message.isNotEmpty) 'message': message};
    print('[PaymentService] POST $u1 body=$body');
    var r = await http.post(u1, headers: _json(h), body: jsonEncode(body));
    print('[PaymentService] ← ${r.statusCode} ${r.body}');
    if (r.statusCode == 200) {
      AppEvents.I.paymentActivity.add(null);
      final b = jsonDecode(r.body);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }

    if (r.statusCode == 404) {
      print('[PaymentService] Retry with slash: $u2');
      r = await http.post(u2, headers: _json(h), body: jsonEncode(body));
      print('[PaymentService] ← ${r.statusCode} ${r.body}');
      if (r.statusCode == 200) {
        AppEvents.I.paymentActivity.add(null);
        final b = jsonDecode(r.body);
        return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
      }
    }
    throw Exception('Reminder failed: ${r.statusCode} ${r.body}');
  }

  /// POST /payments/remind/bulk (UNPAID only for property & period)
  /// Adds a slash-safe fallback to handle 404.
  static Future<void> sendRemindersBulk({
    required int propertyId,
    required String period,
    String? message,
  }) async {
    final h = await _auth();
    final body = {
      'property_id': propertyId,
      'period': period,
      if (message != null && message.isNotEmpty) 'message': message,
    };
    final u1 = Uri.parse('${AppConfig.apiBaseUrl}/payments/remind/bulk');
    final u2 = Uri.parse('${AppConfig.apiBaseUrl}/payments/remind/bulk/');

    print('[PaymentService] POST $u1 body=$body');
    var r = await http.post(u1, headers: _json(h), body: jsonEncode(body));
    print('[PaymentService] ← ${r.statusCode} ${r.body}');
    if (r.statusCode == 200) {
      AppEvents.I.paymentActivity.add(null);
      return;
    }

    if (r.statusCode == 404) {
      print('[PaymentService] Retry with slash: $u2');
      r = await http.post(u2, headers: _json(h), body: jsonEncode(body));
      print('[PaymentService] ← ${r.statusCode} ${r.body}');
      if (r.statusCode == 200) {
        AppEvents.I.paymentActivity.add(null);
        return;
      }
    }
    throw Exception('Bulk reminders failed: ${r.statusCode} ${r.body}');
  }

  /// POST /payments/mpesa/initiate
  static Future<Map<String, dynamic>> initiateMpesa({
    required int leaseId,
    required num amount,
    String? phone,
  }) async {
    final h = await _auth();
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
      AppEvents.I.paymentActivity.add(null);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('MPesa initiation failed: ${r.statusCode} ${r.body}');
  }

  // ---------- Receipts ----------
  // Primary (aligned to backend): /payments/receipt/{payment_id}.pdf
  static String receiptUrl(int paymentId) =>
      '${AppConfig.apiBaseUrl}/payments/receipt/$paymentId.pdf';

  static Future<void> downloadReceiptPdf(int paymentId) async {
    final h = await _auth();
    final headers = {
      ...h,
      'Accept': 'application/pdf',
    };
    final u1 = Uri.parse(receiptUrl(paymentId));
    // Legacy fallback if an older backend path is still live
    final uLegacy = Uri.parse('${AppConfig.apiBaseUrl}/payments/mpesa/receipt/$paymentId.pdf');
    // Optional alternative pattern fallback
    final uAlt = Uri.parse('${AppConfig.apiBaseUrl}/payments/$paymentId/receipt.pdf');

    print('[PaymentService] GET $u1');
    var r = await http.get(u1, headers: headers);
    print('[PaymentService] ← ${r.statusCode}');
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

    if (r.statusCode == 404 || r.statusCode == 422) {
      print('[PaymentService] Fallback GET $uLegacy');
      r = await http.get(uLegacy, headers: headers);
      print('[PaymentService] ← ${r.statusCode}');
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

      print('[PaymentService] Fallback GET $uAlt');
      r = await http.get(uAlt, headers: headers);
      print('[PaymentService] ← ${r.statusCode}');
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
    }

    throw Exception('Failed to download receipt: ${r.statusCode} ${r.body}');
  }
}
