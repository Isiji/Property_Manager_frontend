// lib/services/tenant_service.dart
// Robust Tenant DTO + service with safe decoding and helpful extras.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  return double.tryParse(s);
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

class TenantDto {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? idNumber;
  final int propertyId;
  final int unitId;
  final String? propertyName;   // optional enrichment from backend
  final String? unitLabel;      // aka house / number
  final String? rentStatus;     // "paid" | "partial" | "overdue" | ...
  final double? currentBalance; // +ve = owes, -ve = credit

  TenantDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.propertyId,
    required this.unitId,
    this.email,
    this.idNumber,
    this.propertyName,
    this.unitLabel,
    this.rentStatus,
    this.currentBalance,
  });

  factory TenantDto.fromJson(Map<String, dynamic> j) => TenantDto(
        id: _toInt(j['id']),
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        email: j['email'] as String?,
        idNumber: j['id_number'] as String?,
        propertyId: _toInt(j['property_id']),
        unitId: _toInt(j['unit_id']),
        propertyName: j['property_name'] as String?,
        unitLabel: (j['unit_label'] ?? j['house_number']) as String?,
        rentStatus: (j['rent_status'] ?? j['status'])?.toString(),
        currentBalance: _toDouble(j['current_balance']),
      );
}

class TenantService {
  // ---- URL + headers helpers -------------------------------------------------

  static Uri _u(String path, [Map<String, String>? q]) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized').replace(queryParameters: q);
  }

  static Future<Map<String, String>> _jsonHeaders() async => {
        'Content-Type': 'application/json',
        ...await TokenManager.authHeaders(),
      };

  // ---- CREATE ---------------------------------------------------------------

  static Future<Map<String, dynamic>> createTenant({
    required String name,
    required String phone,
    String? email,
    String? password,
    required int propertyId,
    required int unitId,
    String? idNumber,
  }) async {
    final url = _u('/tenants/');
    final headers = await _jsonHeaders();

    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,           // nullable
      'password': password,     // nullable
      'property_id': propertyId,
      'unit_id': unitId,
      'id_number': idNumber,
    }..removeWhere((_, v) => v == null);

    print('[TenantService] POST $url');
    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body);
      return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Failed to create tenant: ${res.statusCode}\n${res.body}');
  }

  // ---- READ: by phone -------------------------------------------------------

  static Future<Map<String, dynamic>> getByPhone(String phone) async {
    final headers = await _jsonHeaders();
    final url = _u('/tenants/by-phone', {'phone': phone});
    print('[TenantService] GET $url');
    final res = await http.get(url, headers: headers);
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Tenant not found: ${res.statusCode}\n${res.body}');
  }

  // ---- READ: single by id (handy in settings/profile flows) -----------------

  static Future<TenantDto> getTenant(int tenantId) async {
    final headers = await _jsonHeaders();
    final url = _u('/tenants/$tenantId');
    print('[TenantService] GET $url');
    final res = await http.get(url, headers: headers);
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        return TenantDto.fromJson(body);
      }
    }
    throw Exception('Failed to fetch tenant $tenantId: ${res.statusCode}\n${res.body}');
  }

  // ---- READ: me (if your backend exposes /tenants/me) -----------------------

  static Future<TenantDto?> getMe() async {
    final headers = await _jsonHeaders();
    final url = _u('/tenants/me');
    print('[TenantService] GET $url');
    final res = await http.get(url, headers: headers);
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        return TenantDto.fromJson(body);
      }
      return null;
    }
    if (res.statusCode == 404) return null;
    throw Exception('Failed to fetch current tenant: ${res.statusCode}\n${res.body}');
  }

  // ---- READ: list (search + paging + optional filter) -----------------------

  static Future<List<TenantDto>> fetchTenants({
    String? query,
    int page = 1,
    int pageSize = 50,
    int? propertyId,
  }) async {
    final headers = await _jsonHeaders();
    final q = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (query != null && query.isNotEmpty) 'q': query,
      if (propertyId != null) 'property_id': '$propertyId',
    };
    final url = _u('/tenants', q);

    print('[TenantService] GET $url');
    final res = await http.get(url, headers: headers);
    print('[TenantService] ← ${res.statusCode}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = (data is Map<String, dynamic>)
          ? (data['items'] ?? data['results'] ?? data['data'] ?? [])
          : data;
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => TenantDto.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
      return const [];
    }
    throw Exception('Failed to load tenants: ${res.statusCode}\n${res.body}');
  }

  // ---- UPDATE (partial) -----------------------------------------------------

  static Future<Map<String, dynamic>> updateTenant({
    required int tenantId,
    String? name,
    String? phone,
    String? email,
    String? idNumber,
    int? propertyId,
    int? unitId,
  }) async {
    final headers = await _jsonHeaders();
    final url = _u('/tenants/$tenantId');

    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'id_number': idNumber,
      'property_id': propertyId,
      'unit_id': unitId,
    }..removeWhere((_, v) => v == null);

    print('[TenantService] PATCH $url');
    print('[TenantService] payload=$payload');

    final res = await http.patch(url, headers: headers, body: jsonEncode(payload));
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    }
    // Some APIs return 204 No Content for successful updates.
    if (res.statusCode == 204 || (res.statusCode == 202 && (res.body.isEmpty))) {
      return <String, dynamic>{};
    }
    throw Exception('Failed to update tenant: ${res.statusCode}\n${res.body}');
  }

  // ---- DELETE ---------------------------------------------------------------

  static Future<void> deleteTenant(int tenantId) async {
    final headers = await _jsonHeaders();
    final url = _u('/tenants/$tenantId');

    print('[TenantService] DELETE $url');
    final res = await http.delete(url, headers: headers);
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 204) return;
    throw Exception('Failed to delete tenant: ${res.statusCode}\n${res.body}');
  }

  // ---- ASSIGN EXISTING TENANT ----------------------------------------------

  static Future<Map<String, dynamic>> assignExistingTenant({
    required String phone,
    required int unitId,
    required num rentAmount,
    required DateTime startDate,
  }) async {
    final headers = await _jsonHeaders();
    final url = _u('/tenants/assign-existing');

    final payload = {
      'phone': phone,
      'unit_id': unitId,
      'rent_amount': rentAmount,
      'start_date': startDate.toIso8601String().split('T').first,
    };

    print('[TenantService] POST $url');
    print('[TenantService] payload=${jsonEncode(payload)}');

    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body);
      return body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};
    }
    throw Exception('Failed to assign existing tenant: ${res.statusCode}\n${res.body}');
  }
}

// Keep this if you rely on it elsewhere.
class HttpExceptionWithStatus implements Exception {
  final int statusCode;
  final String body;
  HttpExceptionWithStatus(this.statusCode, this.body);
  @override
  String toString() => 'HttpExceptionWithStatus($statusCode, $body)';
}
