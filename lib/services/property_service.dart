import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class PropertyService {
  static Future<List<dynamic>> getPropertiesByLandlord(int landlordId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/landlord/$landlordId');

    // ignore: avoid_print
    print('[PropertyService] GET $url');

    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    // ignore: avoid_print
    print('[PropertyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load properties: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> getPropertyWithUnitsDetailed(int propertyId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/$propertyId/with-units-detailed');

    // ignore: avoid_print
    print('[PropertyService] GET $url');

    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    // ignore: avoid_print
    print('[PropertyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load property details: ${res.statusCode} ${res.body}');
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

    // ignore: avoid_print
    print('[PropertyService] POST $url payload=$payload');

    final res = await http.post(url,
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode(payload));

    // ignore: avoid_print
    print('[PropertyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create property: ${res.statusCode} ${res.body}');
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

    // ignore: avoid_print
    print('[PropertyService] PUT $url payload=$payload');

    final res = await http.put(url,
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode(payload));

    // ignore: avoid_print
    print('[PropertyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update property: ${res.statusCode} ${res.body}');
  }

  static Future<void> deleteProperty(int propertyId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/$propertyId');

    // ignore: avoid_print
    print('[PropertyService] DELETE $url');

    final res = await http.delete(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    // ignore: avoid_print
    print('[PropertyService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete property: ${res.statusCode} ${res.body}');
    }
  }
}
