// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class ManagerService {
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

  /// GET /managers/me
  /// Returns:
  /// {
  ///   manager_user_id,
  ///   manager_id,
  ///   display_name,
  ///   manager_type,
  ///   manager_name,
  ///   staff_role,
  ///   staff_phone
  /// }
  static Future<Map<String, dynamic>> getMe() async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/managers/me');

    print('[ManagerService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[ManagerService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }
    throw Exception('Failed to load manager session: ${_errMsg(res)}');
  }

  /// GET /managers/{id}
  /// NOTE: This is now for the MANAGER ORG profile (PropertyManager org),
  /// not the staff user.
  /// Only call this using managerId (org id), not userId (staff id).
  static Future<Map<String, dynamic>> getManager(int managerId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/managers/$managerId');

    print('[ManagerService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[ManagerService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    }
    throw Exception('Failed to load manager org: ${_errMsg(res)}');
  }
}
