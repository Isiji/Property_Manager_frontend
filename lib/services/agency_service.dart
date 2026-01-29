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

  /// GET /agency/staff
  /// Returns: List<ManagerUserOut>
  static Future<List<dynamic>> listStaff() async {
    final res = await _get(_u('/agency/staff'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load staff: ${_errMsg(res)}');
  }

  /// POST /agency/staff
  /// body: { name, phone, password, email?, id_number?, staff_role? }
  /// Returns: ManagerUserOut
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

  /// PATCH /agency/staff/{staff_id}/deactivate
  /// Returns: { id, active }
  static Future<Map<String, dynamic>> deactivateStaff(int staffId) async {
    final res = await _patch(_u('/agency/staff/$staffId/deactivate'));
    if (res.statusCode == 200) return _decodeMapOrEmpty(res.body);
    throw Exception('Failed to deactivate staff: ${_errMsg(res)}');
  }

  /// POST /agency/properties/{property_id}/assign/{assignee_user_id}
  /// Returns: AssignPropertyOut
  static Future<Map<String, dynamic>> assignPropertyToStaff({
    required int propertyId,
    required int staffUserId,
  }) async {
    final res = await _post(_u('/agency/properties/$propertyId/assign/$staffUserId'));
    _throwIfNotOk(res, 'Assign to staff failed');
    return _decodeMapOrEmpty(res.body);
  }

  // -----------------------------
  // External Agents (linked managers)
  // -----------------------------

  /// GET /agency/agents
  /// Returns: List<LinkAgentOut>
  static Future<List<dynamic>> listLinkedAgents() async {
    final res = await _get(_u('/agency/agents'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load agents: ${_errMsg(res)}');
  }

  /// POST /agency/agents/link
  /// body: { agent_manager_id? , agent_phone? }
  /// Returns: LinkAgentOut
  static Future<Map<String, dynamic>> linkAgent({
    int? agentManagerId,
    String? agentPhone,
  }) async {
    final payload = <String, dynamic>{
      'agent_manager_id': agentManagerId,
      'agent_phone': (agentPhone == null || agentPhone.trim().isEmpty) ? null : agentPhone.trim(),
    }..removeWhere((_, v) => v == null);

    if (payload.isEmpty) {
      throw Exception('Provide agent phone or agent id');
    }

    final res = await _post(_u('/agency/agents/link'), jsonBody: payload);
    _throwIfNotOk(res, 'Link agent failed');
    return _decodeMapOrEmpty(res.body);
  }

  /// PATCH /agency/agents/{agent_manager_id}/unlink
  /// Returns: LinkAgentOut
  static Future<Map<String, dynamic>> unlinkAgent(int agentManagerId) async {
    final res = await _patch(_u('/agency/agents/$agentManagerId/unlink'));
    if (res.statusCode == 200) return _decodeMapOrEmpty(res.body);
    throw Exception('Unlink failed: ${_errMsg(res)}');
  }

  /// POST /agency/properties/{property_id}/assign-external/{agent_manager_id}
  /// Returns: AssignPropertyOut (depends on your backend implementation)
  ///
  /// IMPORTANT:
  /// - This endpoint MUST exist in your backend /docs, otherwise you will get 404.
  /// - If /docs does not show it, add it to agency_router.py and redeploy/restart.
  static Future<Map<String, dynamic>> assignPropertyToExternalAgent({
    required int propertyId,
    required int agentManagerId,
  }) async {
    final res = await _post(_u('/agency/properties/$propertyId/assign-external/$agentManagerId'));
    _throwIfNotOk(res, 'Assign to external agent failed');
    return _decodeMapOrEmpty(res.body);
  }

  // -----------------------------
  // Assignments (for UI display)
  // -----------------------------

  /// GET /agency/properties/assignments/staff
  /// Returns list of active staff assignments
  ///
  /// Suggested backend payload shape:
  /// [
  ///   { "property_id": 4, "assignee_user_id": 12, "assigned_by_user_id": 1, "active": true, "assigned_at": "..." }
  /// ]
  static Future<List<dynamic>> listStaffAssignments() async {
    final res = await _get(_u('/agency/properties/assignments/staff'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load staff assignments: ${_errMsg(res)}');
  }

  /// GET /agency/properties/assignments/external
  /// Returns list of active external agent assignments
  ///
  /// Suggested backend payload shape:
  /// [
  ///   { "property_id": 4, "agent_manager_id": 9, "assigned_by_user_id": 1, "active": true, "assigned_at": "..." }
  /// ]
  static Future<List<dynamic>> listExternalAssignments() async {
    final res = await _get(_u('/agency/properties/assignments/external'));
    if (res.statusCode == 200) return _decodeListOrEmpty(res.body);
    throw Exception('Failed to load external assignments: ${_errMsg(res)}');
  }
}
