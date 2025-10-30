// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class TenantService {
  static Future<Map<String, dynamic>> createTenant({
    required String name,
    required String phone,
    String? email,
    String? password,
    required int propertyId,
    required int unitId,
    String? idNumber, // NEW: optional National ID
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/');
    final headers = {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    };

    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,           // backend allows null
      'password': password,     // backend allows null
      'property_id': propertyId,
      'unit_id': unitId,
      'id_number': idNumber,    // NEW: maps to backend schema field
    }..removeWhere((k, v) => v == null);

    print('[TenantService] POST $url');
    print('[TenantService] payload=$payload');

    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    print('[TenantService] ← ${res.statusCode}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create tenant: ${res.statusCode}\n${res.body}');
  }

  static Future<Map<String, dynamic>> getByPhone(String phone) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/by-phone?phone=$phone');

    print('[TenantService] GET $url');
    final res = await http.get(url, headers: {'Content-Type': 'application/json', ...headers});
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Tenant not found');
  }

  static Future<Map<String, dynamic>> assignExistingTenant({
    required String phone,
    required int unitId,
    required num rentAmount,
    required DateTime startDate,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/tenants/assign-existing');

    final payload = {
      'phone': phone,
      'unit_id': unitId,
      'rent_amount': rentAmount,
      'start_date': startDate.toIso8601String().split('T').first,
    };

    print('[TenantService] POST $url');
    print('[TenantService] payload=${jsonEncode(payload)}');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to assign existing tenant: ${res.statusCode} ${res.body}');
  }
}

// small helper to carry status code outward
class HttpExceptionWithStatus implements Exception {
  final int statusCode;
  final String body;
  HttpExceptionWithStatus(this.statusCode, this.body);
  @override
  String toString() => 'HttpExceptionWithStatus($statusCode, $body)';
}
