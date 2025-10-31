// lib/services/tenant_portal_service.dart
// Gracefully handles 404 on overview/profile so UI still renders.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class TenantPortalService {
  static Map<String, String> _json(Map<String, String> headers) =>
      {'Content-Type': 'application/json', ...headers};

  static Future<Map<String, dynamic>> getOverview() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/me/overview');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    }
    if (r.statusCode == 404) {
      // Backend route not ready yet; show empty dashboard instead of crashing
      return <String, dynamic>{};
    }
    throw Exception('Overview failed: ${r.statusCode} ${r.body}');
  }

  static Future<List<dynamic>> getPayments() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/me/payments');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      return body is List ? body : const [];
    }
    if (r.statusCode == 404) return const [];
    throw Exception('Payments failed: ${r.statusCode} ${r.body}');
  }

  static Future<List<dynamic>> getMaintenance() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/me/maintenance');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      return body is List ? body : const [];
    }
    if (r.statusCode == 404) return const [];
    throw Exception('Maintenance failed: ${r.statusCode} ${r.body}');
  }

  static Future<Map<String, dynamic>> createMaintenance({
    required String title,
    String? description,
  }) async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/me/maintenance');
    final body = {'title': title, 'description': description}..removeWhere((k, v) => v == null);
    final r = await http.post(url, headers: _json(h), body: jsonEncode(body));
    if (r.statusCode == 200 || r.statusCode == 201) {
      final res = jsonDecode(r.body);
      return res is Map ? res.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Create maintenance failed: ${r.statusCode} ${r.body}');
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/me/profile');
    final r = await http.get(url, headers: _json(h));
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    }
    if (r.statusCode == 404) return <String, dynamic>{};
    throw Exception('Profile failed: ${r.statusCode} ${r.body}');
  }

  static Future<Map<String, dynamic>> payThisMonth() async {
    final h = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/me/pay');
    final r = await http.post(url, headers: _json(h));
    if (r.statusCode == 200 || r.statusCode == 202) {
      final body = jsonDecode(r.body);
      return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Pay failed: ${r.statusCode} ${r.body}');
  }
}
