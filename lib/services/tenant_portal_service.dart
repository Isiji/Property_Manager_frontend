import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class TenantPortalService {
  static Map<String, String> _json(Map<String, String> h) => {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        ...h,
      };

  static Uri _uri(String path) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
      queryParameters: {'_t': ts},
    );
  }

  static Future<Map<String, dynamic>> getOverview() async {
    final h = await TokenManager.authHeaders();
    final url = _uri('/tenants/me/overview');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Overview failed: ${r.statusCode} ${r.body}');
  }

  static Future<List<dynamic>> getPayments() async {
    final h = await TokenManager.authHeaders();
    final url = _uri('/tenants/me/payments');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is List) ? b : const [];
    }
    throw Exception('Payments failed: ${r.statusCode} ${r.body}');
  }

  static Future<List<dynamic>> getMaintenance() async {
    final h = await TokenManager.authHeaders();
    final url = _uri('/tenants/me/maintenance');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is List) ? b : const [];
    }
    throw Exception('Maintenance failed: ${r.statusCode} ${r.body}');
  }

  static Future<Map<String, dynamic>> createMaintenance({
    required String description,
  }) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/me/maintenance');
    final body = {'description': description};
    final r = await http.post(url, headers: _json(h), body: jsonEncode(body));
    if (r.statusCode == 201 || r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Create maintenance failed: ${r.statusCode} ${r.body}');
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final h = await TokenManager.authHeaders();
    final url = _uri('/tenants/me/profile');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final b = jsonDecode(r.body);
      return (b is Map) ? b.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Profile failed: ${r.statusCode} ${r.body}');
  }
}