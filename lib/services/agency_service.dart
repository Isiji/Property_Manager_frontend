// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AgencyService {
  static const Duration _timeout = Duration(seconds: 20);

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

  static Map<String, String> _baseHeaders(Map<String, String> authHeaders) {
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      ...authHeaders,
    };
  }

  // -----------------------------
  // Staff
  // -----------------------------
  static Future<List<dynamic>> listStaff() async {
    final auth = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/staff');

    print('[AgencyService] GET $url');

    try {
      final res = await http.get(url, headers: _baseHeaders(auth)).timeout(_timeout);
      print('[AgencyService] ← ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return decoded is List ? decoded : <dynamic>[];
      }
      throw Exception('Failed to load staff: ${_errMsg(res)}');
    } on SocketException {
      throw Exception('Network error: check internet / API URL');
    }
  }

  static Future<Map<String, dynamic>> createStaff({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? idNumber,
    String staffRole = 'manager_staff',
  }) async {
    final auth = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/staff');

    final payload = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'password': password.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'id_number': (idNumber == null || idNumber.trim().isEmpty) ? null : idNumber.trim(),
      'staff_role': staffRole.trim(),
    }..removeWhere((_, v) => v == null);

    print('[AgencyService] POST $url');
    print('[AgencyService] payload: ${jsonEncode(payload)}');

    final res = await http
        .post(url, headers: _baseHeaders(auth), body: jsonEncode(payload))
        .timeout(_timeout);

    print('[AgencyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    throw Exception('Failed to create staff: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> deactivateStaff(int staffId) async {
    final auth = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/staff/$staffId/deactivate');

    print('[AgencyService] PATCH $url');

    final res = await http.patch(url, headers: _baseHeaders(auth)).timeout(_timeout);
    print('[AgencyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    throw Exception('Failed to deactivate staff: ${_errMsg(res)}');
  }

  /// POST /agency/properties/{property_id}/assign/{assignee_user_id}
  static Future<Map<String, dynamic>> assignPropertyToStaff({
    required int propertyId,
    required int staffUserId,
  }) async {
    final auth = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/properties/$propertyId/assign/$staffUserId');

    print('[AgencyService] POST $url');

    final res = await http.post(url, headers: _baseHeaders(auth)).timeout(_timeout);
    print('[AgencyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    throw Exception('Assign to staff failed: ${_errMsg(res)}');
  }

  // -----------------------------
  // External Agents (linked managers)
  // -----------------------------
  /// GET /agency/agents
  static Future<List<dynamic>> listLinkedAgents() async {
    final auth = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/agents');

    print('[AgencyService] GET $url');

    final res = await http.get(url, headers: _baseHeaders(auth)).timeout(_timeout);
    print('[AgencyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return decoded is List ? decoded : <dynamic>[];
    }
    throw Exception('Failed to load agents: ${_errMsg(res)}');
  }

  /// POST /agency/agents/link
  /// body: { agent_manager_id? , agent_phone? }
  static Future<Map<String, dynamic>> linkAgent({
    int? agentManagerId,
    String? agentPhone,
  }) async {
    final auth = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/agents/link');

    final payload = <String, dynamic>{
      'agent_manager_id': agentManagerId,
      'agent_phone': (agentPhone == null || agentPhone.trim().isEmpty) ? null : agentPhone.trim(),
    }..removeWhere((_, v) => v == null);

    if (payload.isEmpty) {
      throw Exception('Provide agent phone or agent id');
    }

    print('[AgencyService] POST $url');
    print('[AgencyService] payload: ${jsonEncode(payload)}');

    final res = await http
        .post(url, headers: _baseHeaders(auth), body: jsonEncode(payload))
        .timeout(_timeout);

    print('[AgencyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    throw Exception('Link agent failed: ${_errMsg(res)}');
  }

  /// PATCH /agency/agents/{agent_manager_id}/unlink
  static Future<Map<String, dynamic>> unlinkAgent(int agentManagerId) async {
    final auth = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/agency/agents/$agentManagerId/unlink');

    print('[AgencyService] PATCH $url');

    final res = await http.patch(url, headers: _baseHeaders(auth)).timeout(_timeout);
    print('[AgencyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    throw Exception('Unlink failed: ${_errMsg(res)}');
  }

  /// POST /agency/properties/{property_id}/assign-external/{agent_manager_id}
  static Future<Map<String, dynamic>> assignPropertyToExternalAgent({
    required int propertyId,
    required int agentManagerId,
  }) async {
    final auth = await TokenManager.authHeaders();
    final url =
        Uri.parse('${AppConfig.apiBaseUrl}/agency/properties/$propertyId/assign-external/$agentManagerId');

    print('[AgencyService] POST $url');

    final res = await http.post(url, headers: _baseHeaders(auth)).timeout(_timeout);
    print('[AgencyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    }
    throw Exception('Assign to external agent failed: ${_errMsg(res)}');
  }
}
