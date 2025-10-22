// lib/services/tenant_service.dart
// Creates & fetches tenants via backend.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class TenantService {
  /// Create a tenant assigned to a property & unit.
  static Future<Map<String, dynamic>> createTenant({
    required String name,
    required String phone,
    String? email,
    String? password, // optional (can be null)
    required int propertyId,
    required int unitId,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/');

    final payload = {
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'property_id': propertyId,
      'unit_id': unitId,
    }..removeWhere((k, v) => v == null);

    // debug
    // ignore: avoid_print
    print('➡️ [TenantService] POST $url');
    // ignore: avoid_print
    print('📦 Payload: $payload');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    // ignore: avoid_print
    print('⬅️ [TenantService] ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create tenant: ${res.statusCode} ${res.body}');
  }
}
