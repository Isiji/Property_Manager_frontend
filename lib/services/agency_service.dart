// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AgencyService {
  static Map<String, dynamic> _tryDecodeMap(String body) {
    try {
      final v = jsonDecode(body);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return {'detail': body};
  }

  static String _errMsg(http.Response res) {
    final m = _tryDecodeMap(res.body);
    final d = (m['detail'] ?? m['message'] ?? res.body).toString();
    return '${res.statusCode} $d';
  }

  /// GET /agency/staff  (admin-only)
  static Future<List<dynamic>> listStaff() async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/staff');

    print('[AgencyService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[AgencyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      return [];
    }
    throw Exception('Failed to load agency staff: ${_errMsg(res)}');
  }

  /// POST /agency/staff (admin-only)
  /// body: { name, phone, email?, password, id_number?, staff_role? }
  static Future<Map<String, dynamic>> createStaff({
    required String name,
    required String phone,
    String? email,
    String? password,
    String? idNumber,
    String staffRole = 'manager_staff', // manager_admin | manager_staff | finance
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/staff');

    final payload = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'password': (password == null || password.trim().isEmpty) ? null : password.trim(),
      'id_number': (idNumber == null || idNumber.trim().isEmpty) ? null : idNumber.trim(),
      'staff_role': staffRole.trim(),
    }..removeWhere((_, v) => v == null);

    print('[AgencyService] POST $url');
    print('[AgencyService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[AgencyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }
    throw Exception('Failed to create staff: ${_errMsg(res)}');
  }

  /// PATCH /agency/staff/{staff_id}/deactivate (admin-only)
  static Future<Map<String, dynamic>> deactivateStaff(int staffId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/staff/$staffId/deactivate');

    print('[AgencyService] PATCH $url');
    final res = await http.patch(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[AgencyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }
    throw Exception('Failed to deactivate staff: ${_errMsg(res)}');
  }
}
