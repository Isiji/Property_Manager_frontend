// lib/services/lease_service.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class LeaseService {
  static Map<String, String> _json(Map<String, String> h) => {
        'Content-Type': 'application/json',
        ...h,
      };

  static Future<Map<String, dynamic>> createLease({
    required int tenantId,
    required int unitId,
    required num rentAmount,
    required String startDate, // YYYY-MM-DD
    int active = 0,
    String? termsText,
  }) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/');
    final body = {
      'tenant_id': tenantId,
      'unit_id': unitId,
      'rent_amount': rentAmount,
      'start_date': startDate,
      'active': active,
      if (termsText != null) 'terms_text': termsText,
    };
    final r = await http.post(url, headers: _json(h), body: jsonEncode(body));
    if (r.statusCode == 200 || r.statusCode == 201) {
      final b = jsonDecode(r.body);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Create lease failed: ${r.statusCode} ${r.body}');
  }

  static Future<void> endLease({required int leaseId, required String endDate}) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId/end');
    final r = await http.post(url, headers: _json(h), body: jsonEncode({'end_date': endDate}));
    if (r.statusCode == 200) return;
    throw Exception('End lease failed: ${r.statusCode} ${r.body}');
  }

  static Future<Map<String, dynamic>> getLease(int leaseId) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Get lease failed: ${r.statusCode} ${r.body}');
  }

  static Future<List<dynamic>> listLeasesForCurrentUser() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/me');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is List) ? b : const [];
    }
    throw Exception('List my leases failed: ${r.statusCode} ${r.body}');
  }

  static Future<void> acceptTerms(int leaseId) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId/accept-terms');
    final r = await http.post(url, headers: _json(h));
    if (r.statusCode == 200) return;
    throw Exception('Accept lease terms failed: ${r.statusCode} ${r.body}');
  }

  static Future<void> activateLease(int leaseId) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId/activate');
    final r = await http.post(url, headers: _json(h));
    if (r.statusCode == 200) return;
    throw Exception('Activate lease failed: ${r.statusCode} ${r.body}');
  }

  static Future<void> downloadLeasePdf(int leaseId) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId.pdf');
    final r = await http.get(url, headers: h);
    if (r.statusCode == 200) {
      final bytes = Uint8List.fromList(r.bodyBytes);
      final blob = html.Blob([bytes], 'application/pdf');
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: blobUrl)
        ..download = 'lease_$leaseId.pdf'
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
      return;
    }
    throw Exception('Lease PDF failed: ${r.statusCode} ${r.body}');
  }
}
