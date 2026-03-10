// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class AuthService {
  /// =============================
  /// REGISTER USER
  /// =============================
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String phone,
    String? email,
    String? password,
    required String role,
    String? propertyCode,
    int? unitId,
    String? unitNumber,
    String? idNumber,
    String? managerType,
    String? companyName,
    String? contactPerson,
    String? officePhone,
    String? officeEmail,
  }) async {
    final r = role.trim().toLowerCase();

    // ✅ public registration is blocked for admin/super_admin
    if (r == 'admin' || r == 'super_admin') {
      throw Exception('$r self-registration is disabled.');
    }

    if (r != 'tenant' && (password == null || password.trim().isEmpty)) {
      throw Exception('Password is required for $r registration.');
    }

    if (r == 'tenant') {
      if (propertyCode == null || propertyCode.trim().isEmpty) {
        throw Exception('Property code is required for tenant registration.');
      }
      final hasUnitId = unitId != null;
      final hasUnitNumber = unitNumber != null && unitNumber.trim().isNotEmpty;
      if (!hasUnitId && !hasUnitNumber) {
        throw Exception('Select a valid unit for tenant registration.');
      }
    }

    final url = Uri.parse(AppConfig.registerEndpoint);

    final payload = <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'password': (password == null || password.trim().isEmpty) ? null : password.trim(),
      'role': r,
      'property_code': (propertyCode == null || propertyCode.trim().isEmpty) ? null : propertyCode.trim(),
      'unit_id': unitId,
      'unit_number': (unitNumber == null || unitNumber.trim().isEmpty) ? null : unitNumber.trim(),
      'id_number': (idNumber == null || idNumber.trim().isEmpty) ? null : idNumber.trim(),
      'manager_type': (managerType == null || managerType.trim().isEmpty) ? null : managerType.trim(),
      'company_name': (companyName == null || companyName.trim().isEmpty) ? null : companyName.trim(),
      'contact_person': (contactPerson == null || contactPerson.trim().isEmpty) ? null : contactPerson.trim(),
      'office_phone': (officePhone == null || officePhone.trim().isEmpty) ? null : officePhone.trim(),
      'office_email': (officeEmail == null || officeEmail.trim().isEmpty) ? null : officeEmail.trim(),
    }..removeWhere((_, v) => v == null);

    print('➡️ Sending to: $url');
    print('📦 Payload: $payload');

    final response = await http.post(
      url,
      headers: const {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(payload),
    );

    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return (data is Map) ? data.cast<String, dynamic>() : <String, dynamic>{};
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  /// =============================
  /// LOGIN USER
  /// =============================
  static Future<Map<String, dynamic>> loginUser({
    required String phone,
    String? password,
    required String role,
  }) async {
    final r = role.trim().toLowerCase();
    final url = Uri.parse(AppConfig.loginEndpoint);

    final payload = <String, dynamic>{
      'phone': phone.trim(),
      'role': r,
      'password': (password == null || password.trim().isEmpty) ? null : password.trim(),
    }..removeWhere((_, v) => v == null);

    print('➡️ Sending login to: $url');
    print('📦 Payload: $payload');

    final response = await http.post(
      url,
      headers: const {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(payload),
    );

    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'];
      final userId = (data['id'] as num?)?.toInt() ?? 0;
      final managerId = (data['manager_id'] as num?)?.toInt();

      if (token == null) {
        throw Exception('Missing access token in response');
      }

      final decoded = JwtDecoder.decode(token);
      final roleFromToken = (decoded['role'] ?? r).toString();

      print('🔑 Decoded Token: $decoded');
      print('✅ Login success: role=$roleFromToken, id=$userId, managerId=$managerId');

      await TokenManager.saveSession(
        token: token,
        role: roleFromToken,
        userId: userId,
        managerId: managerId,
      );

      return {
        'token': token,
        'role': roleFromToken,
        'userId': userId,
        'managerId': managerId,
      };
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
      headers: {
        'Content-Type': 'application/json',
        ...headers,
        'ngrok-skip-browser-warning': 'true',
      },
    );

    print('➡️ Fetching profile');
    print('⬅️ Response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data is Map) ? data.cast<String, dynamic>() : <String, dynamic>{};
    } else {
      throw Exception('Failed to load profile: ${response.body}');
    }
  }
}