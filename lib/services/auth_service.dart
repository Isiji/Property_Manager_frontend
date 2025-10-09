import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AuthService {
  /// Register user
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String phone,
    String? email,
    String? password,
    required String role,
    String? propertyCode,
    int? unitId,
  }) async {
    final url = Uri.parse(AppConfig.registerEndpoint);

    final payload = {
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
      'property_code': propertyCode,
      'unit_id': unitId,
    }..removeWhere((_, v) => v == null);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('➡️ Sending to: $url');
    print('📦 Payload: $payload');
    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  /// Login user
  static Future<void> loginUser({
    required String phone,
    String? password,
    required String role,
  }) async {
    final url = Uri.parse(AppConfig.loginEndpoint);

    final payload = {
      'phone': phone,
      'password': password,
      'role': role,
    }..removeWhere((_, v) => v == null);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('➡️ Sending to: $url');
    print('📦 Payload: $payload');
    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      final userId = data['id'] ?? 0;
      await TokenManager.saveSession(
        token: token,
        role: role,
        userId: userId,
      );
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  static Future<void> logout() async {
    await TokenManager.clearSession();
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final headers = await TokenManager.authHeaders();
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load profile');
    }
  }
}
