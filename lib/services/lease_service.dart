// lib/services/lease_service.dart
// Posts date-only strings (YYYY-MM-DD) to match backend's date type.
//ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_manager_frontend/core/config.dart';
import 'package:property_manager_frontend/utils/token_manager.dart';

class LeaseService {
  static Future<Map<String, dynamic>> createLease({
    required int tenantId,
    required int unitId,
    required num rentAmount,
    required String startDate, // <-- date-only "YYYY-MM-DD"
    int active = 1,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/');
    final headers = {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    };
    final payload = {
      'tenant_id': tenantId,
      'unit_id': unitId,
      'start_date': startDate, // send as date string
      'rent_amount': rentAmount,
      'active': active,
    };

    print('[LeaseService] POST $url');
    print('[LeaseService] payload=$payload');

    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    print('[LeaseService] ← ${res.statusCode}');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create lease: ${res.statusCode}\n${res.body}');
  }

  static Future<Map<String, dynamic>> endLease({
    required int leaseId,
    required String endDate, // <-- date-only "YYYY-MM-DD"
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/leases/$leaseId/end');
    final headers = {
      'Content-Type': 'application/json',
      ...await TokenManager.authHeaders(),
    };
    final payload = {
      'end_date': endDate,
    };

    print('[LeaseService] POST $url');
    print('[LeaseService] payload=$payload');

    final res = await http.post(url, headers: headers, body: jsonEncode(payload));
    print('[LeaseService] ← ${res.statusCode}');
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to end lease: ${res.statusCode}\n${res.body}');
  }
}
