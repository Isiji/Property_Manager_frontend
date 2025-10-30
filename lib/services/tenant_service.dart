// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class TenantDto {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? idNumber;
  final int propertyId;
  final int unitId;
  final String? propertyName;
  final String? unitLabel;         // aka house number
  final String? rentStatus;        // paid | partial | overdue
  final double? currentBalance;

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
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
        phone: (j['phone'] ?? '').toString(),
        email: j['email'] as String?,
        idNumber: j['id_number'] as String?,
        propertyId: j['property_id'] as int,
        unitId: j['unit_id'] as int,
        propertyName: j['property_name'] as String?,
        unitLabel: (j['unit_label'] ?? j['house_number']) as String?,
        rentStatus: (j['rent_status'] ?? j['status'])?.toString(),
        currentBalance: j['current_balance'] == null
            ? null
            : double.tryParse(j['current_balance'].toString()),
      );
}

class TenantService {
  static Uri _u(String path, [Map<String, String>? q]) {
    final b = StringBuffer(AppConfig.apiBaseUrl);
    if (!AppConfig.apiBaseUrl.endsWith('/')) b.write('/');
    b.write(path.startsWith('/') ? path.substring(1) : path);
    return Uri.parse(b.toString()).replace(queryParameters: q);
  }

  /// ------------------------------------------
  /// CREATE
  /// ------------------------------------------
  static Future<Map<String, dynamic>> createTenant({
    required String name,
    required String phone,
    String? email,
    String? password,
    required int propertyId,
    required int unitId,
    String? idNumber, // optional National ID
  }) async {
    final url = _u('/tenants/');
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
      'id_number': idNumber,    // snake_case
    }..removeWhere((_, v) => v == null);

    print('[TenantService] POST $url');
    print('[TenantService] payload=$payload');

    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    print('[TenantService] ← ${res.statusCode}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create tenant: ${res.statusCode}\n${res.body}');
  }

  /// ------------------------------------------
  /// READ: by phone
  /// ------------------------------------------
  static Future<Map<String, dynamic>> getByPhone(String phone) async {
    final headers = await TokenManager.authHeaders();
    final url = _u('/tenants/by-phone', {'phone': phone});

    print('[TenantService] GET $url');
    final res = await http.get(url, headers: {'Content-Type': 'application/json', ...headers});
    print('[TenantService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Tenant not found');
  }

  /// ------------------------------------------
  /// READ: list tenants (with search & paging)
  /// ------------------------------------------
  static Future<List<TenantDto>> fetchTenants({
    String? query,
    int page = 1,
    int pageSize = 50,
    int? propertyId, // optional filter
  }) async {
    final headers = await TokenManager.authHeaders();
    final q = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (query != null && query.isNotEmpty) 'q': query,
      if (propertyId != null) 'property_id': '$propertyId',
    };
    final url = _u('/tenants', q);

    print('[TenantService] GET $url');

    final res = await http.get(url, headers: {'Content-Type': 'application/json', ...headers});
    print('[TenantService] ← ${res.statusCode}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = (data is Map<String, dynamic>)
          ? (data['items'] ?? data['results'] ?? data['data'] ?? [])
          : data;
      return (list as List).map((e) => TenantDto.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load tenants: ${res.statusCode}\n${res.body}');
  }

  /// ------------------------------------------
  /// UPDATE (partial)
  /// ------------------------------------------
  static Future<Map<String, dynamic>> updateTenant({
    required int tenantId,
    String? name,
    String? phone,
    String? email,
    String? idNumber,
    int? propertyId,
    int? unitId,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    };
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
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update tenant: ${res.statusCode}\n${res.body}');
  }

  /// ------------------------------------------
  /// DELETE
  /// ------------------------------------------
  static Future<void> deleteTenant(int tenantId) async {
    final headers = await TokenManager.authHeaders();
    final url = _u('/tenants/$tenantId');

    print('[TenantService] DELETE $url');
    final res = await http.delete(url, headers: {'Content-Type': 'application/json', ...headers});
    print('[TenantService] ← ${res.statusCode}');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete tenant: ${res.statusCode}\n${res.body}');
    }
  }

  /// ------------------------------------------
  /// ASSIGN EXISTING TENANT
  /// ------------------------------------------
  static Future<Map<String, dynamic>> assignExistingTenant({
    required String phone,
    required int unitId,
    required num rentAmount,
    required DateTime startDate,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = _u('/tenants/assign-existing');

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

// small helper to carry status code outward (kept from your file)
class HttpExceptionWithStatus implements Exception {
  final int statusCode;
  final String body;
  HttpExceptionWithStatus(this.statusCode, this.body);
  @override
  String toString() => 'HttpExceptionWithStatus($statusCode, $body)';
}
