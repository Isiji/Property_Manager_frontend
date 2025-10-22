// lib/services/lease_service.dart
// Creates leases (assign tenant to unit with rent & start_date).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LeaseService {
  /// Create a lease. Backend should mark as active (1) by default,
  /// but we send it explicitly for clarity.
  static Future<Map<String, dynamic>> createLease({
    required int tenantId,
    required int unitId,
    required num rentAmount,
    DateTime? startDate, // optional
    int active = 1,
  }) async {
    final headers = await TokenManager.authHeaders();
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/');

    final payload = {
      'tenant_id': tenantId,
      'unit_id': unitId,
      'rent_amount': rentAmount,
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      'active': active,
    };

    // debug
    // ignore: avoid_print
    print('➡️ [LeaseService] POST $url');
    // ignore: avoid_print
    print('📦 Payload: $payload');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...headers},
      body: jsonEncode(payload),
    );

    // ignore: avoid_print
    print('⬅️ [LeaseService] ${res.statusCode} ${res.body}');

    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create lease: ${res.statusCode} ${res.body}');
  }
}
