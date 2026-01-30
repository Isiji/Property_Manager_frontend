// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AgencyService {
  static const Duration _timeout = Duration(seconds: 20);

  // -----------------------------
  // Helpers
  // -----------------------------
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

  static Uri _u(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  static Future<http.Response> _get(Uri url) async {
    final auth = await TokenManager.authHeaders();
    print('[AgencyService] GET $url');
    try {
      final res = await http.get(url, headers: _baseHeaders(auth)).timeout(_timeout);
      print('[AgencyService] ← ${res.statusCode} ${res.body}');
      return res;
    } on SocketException {
      throw Exception('Network error: check internet / API URL');
    }
  }

  static Future<http.Response> _post(Uri url, {Map<String, dynamic>? jsonBody}) async {
    final auth = await TokenManager.authHeaders();
    print('[AgencyService] POST $url');
    if (jsonBody != null) print('[AgencyService] payload: ${jsonEncode(jsonBody)}');
    try {
      final res = await http
          .post(
            url,
            headers: _baseHeaders(auth),
            body: jsonBody == null ? null : jsonEncode(jsonBody),
          )
          .timeout(_timeout);
      print('[AgencyService] ← ${res.statusCode} ${res.body}');
      return res;
    } on SocketException {
      throw Exception('Network error: check internet / API URL');
    }
  }

  static Future<http.Response> _patch(Uri url, {Map<String, dynamic>? jsonBody}) async {
    final auth = await TokenManager.authHeaders();
    print('[AgencyService] PATCH $url');
    if (jsonBody != null) print('[AgencyService] payload: ${jsonEncode(jsonBody)}');
    try {
      final res = await http
          .patch(
            url,
            headers: _baseHeaders(auth),
            body: jsonBody == null ? null : jsonEncode(jsonBody),
          )
          .timeout(_timeout);
      print('[AgencyService] ← ${res.statusCode} ${res.body}');
      return res;
    } on SocketException {
      throw Exception('Network error: check internet / API URL');
    }
  }

  static List<dynamic> _decodeListOrEmpty(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is List ? decoded : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  static Map<String, dynamic> _decodeMapOrEmpty(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static void _throwIfNotOk(http.Response res, String prefix) {
    if (res.statusCode == 200 || res.statusCode == 201) return;
    throw Exception('$prefix: ${_errMsg(res)}');
  }

  // -----------------------------
  // Staff
  // -----------------------------
  static Future<List<dynamic>> listStaff() async {
    final res = await _get(_u('/agency/staff'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load staff: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> createStaff({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? idNumber,
    String staffRole = 'manager_staff',
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'password': password.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'id_number': (idNumber == null || idNumber.trim().isEmpty) ? null : idNumber.trim(),
      'staff_role': staffRole.trim(),
    }..removeWhere((_, v) => v == null);

    final res = await _post(_u('/agency/staff'), jsonBody: payload);
    _throwIfNotOk(res, 'Failed to create staff');
    return _decodeMapOrEmpty(res.body);
  }

  static Future<Map<String, dynamic>> deactivateStaff(int staffId) async {
    final res = await _patch(_u('/agency/staff/$staffId/deactivate'));
    if (res.statusCode == 200) return _decodeMapOrEmpty(res.body);
    throw Exception('Failed to deactivate staff: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> assignPropertyToStaff({
    required int propertyId,
    required int staffUserId,
  }) async {
    final res = await _post(_u('/agency/properties/$propertyId/assign/$staffUserId'));
    _throwIfNotOk(res, 'Assign to staff failed');
    return _decodeMapOrEmpty(res.body);
  }

  /// PATCH /agency/properties/{property_id}/unassign-staff
  static Future<Map<String, dynamic>> unassignStaffFromProperty({
    required int propertyId,
  }) async {
    final res = await _patch(_u('/agency/properties/$propertyId/unassign-staff'));
    if (res.statusCode == 200) return _decodeMapOrEmpty(res.body);
    throw Exception('Unassign staff failed: ${_errMsg(res)}');
  }

  // -----------------------------
  // External Agents (linked managers)
  // -----------------------------
  static Future<List<dynamic>> listLinkedAgents() async {
    final res = await _get(_u('/agency/agents'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load agents: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> linkAgent({
    int? agentManagerId,
    String? agentPhone,
  }) async {
    final payload = <String, dynamic>{
      'agent_manager_id': agentManagerId,
      'agent_phone': (agentPhone == null || agentPhone.trim().isEmpty) ? null : agentPhone.trim(),
    }..removeWhere((_, v) => v == null);

    if (payload.isEmpty) throw Exception('Provide agent phone or agent id');

    final res = await _post(_u('/agency/agents/link'), jsonBody: payload);
    _throwIfNotOk(res, 'Link agent failed');
    return _decodeMapOrEmpty(res.body);
  }

  static Future<Map<String, dynamic>> unlinkAgent(int agentManagerId) async {
    final res = await _patch(_u('/agency/agents/$agentManagerId/unlink'));
    if (res.statusCode == 200) return _decodeMapOrEmpty(res.body);
    throw Exception('Unlink failed: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> assignPropertyToExternalAgent({
    required int propertyId,
    required int agentManagerId,
  }) async {
    final res = await _post(_u('/agency/properties/$propertyId/assign-external/$agentManagerId'));
    _throwIfNotOk(res, 'Assign to external agent failed');
    return _decodeMapOrEmpty(res.body);
  }

  /// PATCH /agency/properties/{property_id}/unassign-external
  static Future<Map<String, dynamic>> unassignExternalFromProperty({
    required int propertyId,
  }) async {
    final res = await _patch(_u('/agency/properties/$propertyId/unassign-external'));
    if (res.statusCode == 200) return _decodeMapOrEmpty(res.body);
    throw Exception('Unassign external agent failed: ${_errMsg(res)}');
  }

  // -----------------------------
  // Assignments (for UI display)
  // -----------------------------
  static Future<List<dynamic>> listStaffAssignments() async {
    final res = await _get(_u('/agency/assignments/staff'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load staff assignments: ${_errMsg(res)}');
  }

  static Future<List<dynamic>> listExternalAssignments() async {
    final res = await _get(_u('/agency/assignments/external'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load external assignments: ${_errMsg(res)}');
  }
}
