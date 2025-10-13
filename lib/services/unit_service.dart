import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class UnitService {
  static Future<List<dynamic>> getUnitsByProperty(int propertyId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/units/property/$propertyId');

    // ignore: avoid_print
    print('[UnitService] GET $url');

    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    // ignore: avoid_print
    print('[UnitService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load units: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> createUnit({
    required int propertyId,
    required String number,
    required String rentAmount,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/units/');

    final payload = {
      'property_id': propertyId,
      'number': number,
      'rent_amount': rentAmount,
    };

    // ignore: avoid_print
    print('[UnitService] POST $url payload=$payload');

    final res = await http.post(url,
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode(payload));

    // ignore: avoid_print
    print('[UnitService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create unit: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> updateUnit({
    required int unitId,
    String? number,
    String? rentAmount,
    int? occupied,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/units/$unitId');

    final payload = {
      'number': number,
      'rent_amount': rentAmount,
      'occupied': occupied,
    }..removeWhere((k, v) => v == null);

    // ignore: avoid_print
    print('[UnitService] PUT $url payload=$payload');

    final res = await http.put(url,
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode(payload));

    // ignore: avoid_print
    print('[UnitService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update unit: ${res.statusCode} ${res.body}');
  }

  static Future<void> deleteUnit(int unitId) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/units/$unitId');

    // ignore: avoid_print
    print('[UnitService] DELETE $url');

    final res = await http.delete(url, headers: {
      'Content-Type': 'application/json',
      ...headers,
    });

    // ignore: avoid_print
    print('[UnitService] ← ${res.statusCode} ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete unit: ${res.statusCode} ${res.body}');
    }
  }
}
