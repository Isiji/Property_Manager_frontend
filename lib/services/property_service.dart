// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class PropertyService {
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

  // -----------------------------
  // Properties
  // -----------------------------
  static Future<List<dynamic>> getPropertiesByLandlord(int landlordId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/landlord/$landlordId');

    print('[PropertyService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[PropertyService] ← ${res.statusCode}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load properties: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> getPropertyWithUnitsDetailed(int propertyId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/$propertyId/with-units-detailed');

    print('[PropertyService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[PropertyService] ← ${res.statusCode}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load property details: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> createProperty({
    required String name,
    required String address,
    required int landlordId,
    int? managerId,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/');

    final payload = {
      'name': name,
      'address': address,
      'landlord_id': landlordId,
      'manager_id': managerId,
    }..removeWhere((k, v) => v == null);

    print('[PropertyService] POST $url');
    print('[PropertyService] payload: ${jsonEncode(payload)}');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[PropertyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create property: ${_errMsg(res)}');
  }

  static Future<Map<String, dynamic>> updateProperty({
    required int propertyId,
    String? name,
    String? address,
    int? managerId,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/$propertyId');

    final payload = {
      'name': name,
      'address': address,
      'manager_id': managerId,
    }..removeWhere((k, v) => v == null);

    print('[PropertyService] PUT $url');
    print('[PropertyService] payload: ${jsonEncode(payload)}');

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[PropertyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update property: ${_errMsg(res)}');
  }

  static Future<void> deleteProperty(int propertyId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/$propertyId');

    print('[PropertyService] DELETE $url');

    final res = await http.delete(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[PropertyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete property: ${_errMsg(res)}');
    }
  }

  // -----------------------------
  // Property Managers (REAL BACKEND FLOW)
  // -----------------------------

  /// Search property managers using your backend: GET /managers/search?q=...
  static Future<List<dynamic>> searchPropertyManagers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/managers/search?q=${Uri.encodeComponent(q)}');

    print('[PropertyService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[PropertyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to search property managers: ${_errMsg(res)}');
  }

  /// Assign or unassign a manager to a property: PUT /properties/{id}/assign-manager
  static Future<Map<String, dynamic>> assignPropertyManager({
    required int propertyId,
    required int? managerId, // null => unassign
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/$propertyId/assign-manager');

    final payload = {'manager_id': managerId};

    print('[PropertyService] PUT $url');
    print('[PropertyService] payload: ${jsonEncode(payload)}');

    final res = await http.put(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    print('[PropertyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to assign property manager: ${_errMsg(res)}');
  }

  /// Optional convenience (if you added it): GET /properties/{id}/property-manager
  static Future<Map<String, dynamic>?> getAssignedPropertyManager(int propertyId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/$propertyId/property-manager');

    print('[PropertyService] GET $url');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    print('[PropertyService] ← ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded == null) return null;
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    }
    if (res.statusCode == 404) return null; // endpoint not deployed or property missing
    throw Exception('Failed to load assigned manager: ${_errMsg(res)}');
  }
}
