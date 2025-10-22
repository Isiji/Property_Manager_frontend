// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class TenantService {
  /// Create a tenant
  /// Backend (from your router): POST /tenants/
  /// Payload: { name, phone, email?, property_id, unit_id }
  static Future<Map<String, dynamic>> createTenant({
    required String name,
    required String phone,
    String? email,
    required int propertyId,
    required int unitId,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/');

    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'property_id': propertyId,
      'unit_id': unitId,
    }..removeWhere((k, v) => v == null);

    print('[TenantService] POST $url');
    print('[TenantService] payload=$payload');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create tenant: ${res.statusCode} ${res.body}');
  }

  /// Get a tenant by id
  static Future<Map<String, dynamic>> getTenant(int tenantId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/$tenantId');

    print('[TenantService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load tenant: ${res.statusCode} ${res.body}');
  }

  /// Update a tenant
  static Future<Map<String, dynamic>> updateTenant({
    required int tenantId,
    String? name,
    String? phone,
    String? email,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/$tenantId');

    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
    }..removeWhere((k, v) => v == null);

    print('[TenantService] PUT $url');
    print('[TenantService] payload=$payload');

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update tenant: ${res.statusCode} ${res.body}');
  }

  /// Delete a tenant
  static Future<void> deleteTenant(int tenantId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/$tenantId');

    print('[TenantService] DELETE $url');
    final res = await http.delete(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete tenant: ${res.statusCode} ${res.body}');
    }
  }
}
