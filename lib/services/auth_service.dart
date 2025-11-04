// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AuthService {
  /// =============================
  /// 🔹 REGISTER USER
  /// =============================
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String phone,
    String? email,
    String? password,
    required String role,
    String? propertyCode,
    int? unitId,            // legacy (kept for compatibility)
    String? unitNumber,     // NEW (preferred)
    String? idNumber,       // optional National ID
  }) async {
    if (role != 'tenant' && (password == null || password.isEmpty)) {
      throw Exception('Password is required for $role registration.');
    }

    final url = Uri.parse(AppConfig.registerEndpoint);
    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
      'property_code': propertyCode,
      // prefer number; send id only when number is absent
      'unit_number': unitNumber,
      'unit_id': unitNumber == null ? unitId : null,
      'id_number': idNumber,
    }..removeWhere((_, v) => v == null);

    print('➡️ Sending to: $url');
    print('📦 Payload: $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  /// =============================
  /// 🔹 LOGIN USER
  /// =============================
  static Future<Map<String, dynamic>> loginUser({
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

    print('➡️ Sending login to: $url');
    print('📦 Payload: $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'];
      final userId = data['id'] ?? 0;

      if (token == null) {
        throw Exception('Missing access token in response');
      }

      // Decode JWT to read role (fallback to requested role)
      final decoded = JwtDecoder.decode(token);
      final roleFromToken = decoded['role'] ?? role;

      print('🔑 Decoded Token: $decoded');
      print('✅ Login success: role=$roleFromToken, id=$userId');

      // Persist session
      await TokenManager.saveSession(
        token: token,
        role: roleFromToken,
        userId: userId,
      );

      return {'token': token, 'role': roleFromToken, 'userId': userId};
    } else {
      print('❌ Login failed: ${response.statusCode} ${response.body}');
      throw Exception('Login failed: ${response.body}');
    }
  }

  static Future<void> logout() async {
    print('🚪 Logging out and clearing session...');
    await TokenManager.clearSession();
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final headers = await TokenManager.authHeaders();
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/profile'),
      headers: {'Content-Type': 'application/json', ...headers},
    );

    print('➡️ Fetching profile');
    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load profile');
    }
  }
}
